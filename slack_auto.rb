# このプログラムは、とあるコミュニティで、コミュニティの発展に必要な機能をモブプログラミングしたときにできたものです（飲み会的に）。
# slackと通信し、slackで行動のない人をワークスペースから削除します。
# 1. slackの全チャンネルの過去ログを参照し、行動のない人を見つけ出し、警告します
# 2. 警告の一定時間後に、行動のなかった人を、kickします
# なお、これは aws lambda で動く予定です

require 'net/http'
require 'json'
require "pry"

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
  uri = URI("https://slack.com/api/channels.history?channel=#{cannel}&token=#{token}&pretty=1")
  Net::HTTP.get(uri)
end

def get_user_ids_from_channel_hist(ch_hist)
  JSON.parse(ch_hist)["messages"].map{|msg| "#{msg["user"]}"}
end

def ask_non_active_user(user)
  url = URI('https://hooks.slack.com/services/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')
  res = Net::HTTP.post(url, message(user).to_json, "Content-type" => "application/json")
end

def message(user_id)
  {
    "attachments": [
      {
        title: "<@#{user_id}> さん、お元気ですか？",
        text: "commitee-regist の運用自動化により、一定期間、反応がない場合に、自動削除の対象となります。このままなにもないと、明日あたりに、 `/kick` コマンドが自動で実行される可能性があります。"
      }
    ]
  }
end

puts "#{ARGV[0]}"
puts "#{ARGV[1]}"

# インテグレーションするたびに排除してはいけないユーザーIDを追加してください
# 例→ UBVFBGH8X: Google Drive
special_user = ["UBVFBGH8X"]

# ここからメインの手続き
list = channel_list
ch_ids = JSON.parse(list)["channels"].map{|ch| ch["id"]}

active_users = []
ch_ids.each do |ch_id|
  ch_hist = get_channel_hist(ch_id)
  active_users << get_user_ids_from_channel_hist(ch_hist)
end
active_users.flatten!.uniq!

non_active_users = user_list - active_users - special_user
non_active_users.each{|non_a_user| ask_non_active_user(non_a_user)}

# binding.pry
