# このプログラムは、とあるコミュニティで、コミュニティの発展に必要な機能をモブプログラミングしたときにできたものです（飲み会的に）。
# slackと通信し、slackで行動のない人をワークスペースから削除します。
# 1. slackの全チャンネルの３ヶ月間の過去ログを参照し、発言のない人を#最近ご無沙汰チャンネルへ、招待します。
# 2. その後どうするかは運用次第（未定）
# なお、これは aws lambda で動く予定です
#
# TODO:
# [ ] polly botのユーザーIDを調べる


class SlackKickoutOps
  require 'net/http'
  require 'json'
  require "pry"
  require 'date'

  # #general
  # https://hooks.slack.com/services/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
  # #最近ご無沙汰のurl
  # https://hooks.slack.com/services/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
  def initialize(token)
    @slack_notify_url = 'https://hooks.slack.com/services/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'
    @archive_channel = 'CCRBYV0CV' # 削除対象者チャンネル
    @token = token
  end

  # メインの手続きで使うメソッド群
  def user_list(token)
    uri = URI("https://slack.com/api/users.list?token=#{token}")
    JSON.parse(Net::HTTP.get(uri))["members"].map{|member| "#{member["id"]}"}
  end

  def channel_list(token)
    uri = URI("https://slack.com/api/channels.list?token=#{token}")
    Net::HTTP.get(uri)
  end

  def get_channel_hist(cannel: cannel, token: token)
    oldest = (Date.today - 90).strftime('%s')
    uri = URI("https://slack.com/api/channels.history?channel=#{cannel}&token=#{token}&oldest=#{oldest}&pretty=1")
    Net::HTTP.get(uri)
  end

  def get_user_ids_from_channel_hist(ch_hist)
    JSON.parse(ch_hist)["messages"].map{|msg| "#{msg["user"]}"}
  end

  def ask_non_active_user(user)
    url = URI(@slack_notify_url)
    res = Net::HTTP.post(url, message(user).to_json, "Content-type" => "application/json")
  end

  def message(user_id)
    {
      "attachments": [
        {
          title: "<@#{user_id}> さん、お元気ですか？",
          text: "本チャンネルは一定期間、活動がないアカウントが参加するチャンネルです。誤ってチャンネルに参加させられた方はお手数ですが、自分でチャンネルから退出してください。"
        }
      ]
    }
  end

  def json_data(user)
     {
       token: @token,
       channel: @archive_channel,
       user: user
     }.to_json
  end

  def invite_user(user)
    res =  Net::HTTP.post URI("https://slack.com/api/channels.invite"),
                     { user: user, channel: @archive_channel }.to_json,
                     {"Content-Type" => "application/json", 'charset' => 'text/plain', 'Authorization' => "Bearer #{@token}"}

  end
end

# token
token = ARGV[0]

slack_ops = SlackKickoutOps.new(token)

# インテグレーションするたびに排除してはいけないユーザーIDを追加してください
# 例→ UBVFBGH8X: Google Drive
special_user = ["UBVFBGH8X"]

# ここからメインの手続き
list = slack_ops.channel_list(token)
ch_ids = JSON.parse(list)["channels"].map{|ch| ch["id"]}

active_users = []
ch_ids.each do |ch_id|
  ch_hist = slack_ops.get_channel_hist(cannel: ch_id, token: token)
  active_users << slack_ops.get_user_ids_from_channel_hist(ch_hist)
end
active_users.flatten!.uniq!

non_active_users = slack_ops.user_list(token) - active_users - special_user
non_active_users.each do |non_a_user|
  slack_ops.invite_user(non_a_user)
  slack_ops.ask_non_active_user(non_a_user)
end
