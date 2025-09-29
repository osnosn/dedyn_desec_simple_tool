#!/bin/bash

# 需要的命令支持
# require "apt install jq" jq轻量级命令行json解析器
# require "apt install curl"  curl
# require "apt install util-linux"  getopt
# require "apt install coreutils"  dirname,readlink,date,ls,
# ##require "apt install perl"  json_pp ;(json_pp未使用,改用jq) 
#    三个写法是等效的,可以替换'json_pp -f json' 'python3 -m json.tool' 'jq .'

VERSION='v1.1'
VERSION_DATE='2025-09'

#DDNS open source/desic.io/register account/need to receive email first, click on the activation link to set password/suggest setting 2FA to ensure account security/
EMAIL_USR='xxx@email'      #desec.io USERNAME
EMAIL_PWD='xxxxxxxxxx'     #PASSWORD

# api_token with high authority
admin_token='ac------------------------tH'   #main_token
# Long term valid api_token. If it is logged out, you need to log in to desic.io to create a new api_token, and then update the token in the ddns script
# api_token without perm_create_domain, perm_delete_domain, perm_manage_tokens; Cannot operate on list_tokens, show_account_info. Other operation is OK.
api_token='yy------------------------RR' #update_token,(No manage tokens,No create/delete domains; Can create rrset records.)

#============================================
selfpath=$(/usr/bin/dirname $(/bin/readlink -f -- $0))
opt='-sS'  #默认不显示curl的progress进度
#opt=''
token=$api_token

#获取 login 得到的 "临时login_token" ,通常7 天有效, 1小时不用就失效
token_tmp_file=${selfpath}/tokens.temporary
token='vz----------------------gKHE' #临时login_token, 测试用
if [ -f "$token_tmp_file" ]; then
   read token <  <(tail -n 1 "$token_tmp_file")
   token=${token%\"}
   token=${token#\"}
   filemode=$(ls -l $token_tmp_file|cut -d' ' -f1)
   if [ "$filemode" != '-rw-------' ]; then
      chmod 600 ${token_tmp_file}
   fi
fi
#echo $token

login_token() {
   # login 得到的是login_token (mfa:false),未通过2FA验证之前,权限很低,并且仅 7天有效,1小时不用就失效.
   # 非 API token, (mfa:null)
   #--- login ---- 并获取1小时有效的token
   echo " Get Temporary login TOKEN."
   local token_buf=$(
   curl ${opt} -X POST 'https://desec.io/api/v1/auth/login/' \
      --header "Content-Type: application/json" --data-binary \
      '{"email": "'$EMAIL_USR'", "password": "'$EMAIL_PWD'"}'
   )
   logs login_token "$token_buf"
   #echo "$token_buf" | json_pp -f json >> ${token_tmp_file}
   #echo "$token_buf" | json_pp -f json
   echo "$token_buf" | jq .token >> ${token_tmp_file}
   echo "$token_buf" | jq .token
   #echo '手工copy这个 token 到脚本的前部，"临时login_token"的位置。'
   echo ' 临时login_token 已经被保存在' ${token_tmp_file}
   echo ' "临时login_token" ,通常7 天有效, 1小时不用就失效。权限很低。'
   echo '    可以更新IP, create/modify/del rrset(cname,txt);'
   echo '  不能 list domain, list stats, list rrset, list zonefile, list token.'
   echo '  使用完后，记得 注销这个 临时login_token。否则会留下一个失效的token，只能手工登录网站删除它。'
}
logout_token() {
   #---注销token---成功返回""空(非json),失败才返回json---
   if [ "$token" = "$admin_token" ]; then
      echo
      echo '  这是个admin api_token，不建议注销它。'
      echo '  除非你想更换一个。'
      echo '  需要手工登录desec.io，手工重新生成一个admin api_token,'
      echo '  并删除旧的admin api_token。'
      echo
   else
      echo ' 注销 token,' "$token"
      echo '  注销后，用脚本重新生成一个普通的api_token。'
      echo '  然后还要更新各个ddns的脚本，检查它们使用的 api_token。'
      echo '    或者,手工登录desec.io，手工重新生成一个api_token。'
      local buf=$(
      curl ${opt} -X POST 'https://desec.io/api/v1/auth/logout/' \
         --header "Authorization: Token ${token}" ; echo
      )
      echo ' 注销token, 成功返回""空(非json),失败才返回json'
      logs logout_tokens $token "$buf"
      if [ -z "$buf" ]; then 
         echo ' ""空'
      else
         echo " $buf"
      fi
   fi
}

account_info() {
   #--获取账户信息---用admin_token操作获取
   echo " Account info."
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/auth/account/' \
      --header "Authorization: Token ${token}"
   )
   logs account_info "$buf"
   #echo "$buf" |json_pp -f json 
   echo "$buf" | jq .
}
update_ddns() {
   #--- update ddns ------
   # 通常使用api_token，用临时login_token也可以
   # 两种更新ddns IP的例子
   # 不改变的ip用"preserve",表示对应的ip4/ip6不改变。如: myipv4=preserve&myipv6=::1  
   local domain="$1"
   local ipv4="$2"
   local ipv6="$3"
   echo " Update IPs."
   local buf_header="DOMAIN: $domain, ipv4: $ipv4, ipv6: $ipv6"
   echo " $buf_header"
   local buf=$(
      curl ${opt} --user ${domain}:${token} "https://update.dedyn.io/?myipv4=${ipv4}&myipv6=${ipv6}"
      #curl ${opt} "https://update.dedyn.io/?hostname=test.dedyn.io&myipv4=127.0.0.1&myipv6=::2" --header "Authorization: Token ${token}" 
   )
   logs update_ddns "$buf_header" "$buf"
   echo " $buf"
}

list_tokens() {
   #--list tokens----
   echo " List tokens."
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/auth/tokens/' \
      --header "Authorization: Token ${token}"
   )
   logs list_tokens "$buf"
   #echo "$buf" |json_pp -f json  #正常返回,第一层是数组; 如果出错,第一层是字典;
   # 不加?, jq会报一个错误，无法在数组array查找 string的key;
   { read num; read detail; } <  <( echo "$buf" | jq '.|length, has("detail")?' ) #读两行
      if [ "$num" -eq 1 -a "$detail" = "true" ]; then
         echo " $buf"
         return
      fi
   #echo "$buf" | json_pp -f json
   #echo "$buf" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin),indent=3))"
   #echo "$buf" | python3 -c "import sys, json; buf=json.load(sys.stdin); [print(vv['id']) for vv in buf];"
   #echo "$buf" | python3 -c "import sys, json; buf=json.load(sys.stdin); print([vv['id'] for vv in buf]);"
   if [ "$DETAIL" = "yes" ]; then
      echo "$buf" | jq .
   else
      #echo "$buf" | jq '[.[]|{id:.id, name:.name, max_age:.max_age, max_unused_period:.max_unused_period, mfa:.mfa, perm_create_domain:.perm_create_domain, perm_delete_domain:.perm_delete_domain, perm_manage_tokens:.perm_manage_tokens, is_valid:.is_valid }]'
      echo "$buf" | jq -r '[" --------------- id -----------------","name","age","unused","mfa","建域名","删域名","管token","有效"], (.[]|[" "+.id, .name, (.max_age|@text), (.max_unused_period|@text), (.mfa|@text), .perm_create_domain, .perm_delete_domain, .perm_manage_tokens, .is_valid] )|@tsv'
   fi
   echo
   #eval "$buf"
}
show_token() {
   #--show token----
   local token_id=$1
   echo " Show token. id: $token_id"
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/auth/tokens/'${token_id}'/' \
      --header "Authorization: Token ${token}"
   )
   logs show_token "$buf"
   #echo "$buf" | jq -M .  # no color
   echo "$buf" | jq .
}
show_token_conf() {
   echo '
{
  "name": "token_name",
  "max_age": "365 00:00:00",
  "max_unused_period": null,
  "perm_create_domain": true,
  "perm_delete_domain": false,
  "perm_manage_tokens": false,
  "auto_policy": false,
  "allowed_subnets": [
    "0.0.0.0/0",
    "::/0"
  ]
}
' |jq .
echo '  ---OR---'
echo '
{
  "name": "token_name",
  "perm_create_domain": true
}
' |jq .
echo '
 If "--token-conf <file>" is used, "-s token_name" will be ignored.
 Please set "token_name" in token-conf <file>.
 The  ITEM/FLAG  will use DEFAULT values if it is not set.
   "name"               DEFAULT  "",
   "max_age"            DEFAULT  null,
   "max_unused_period"  DEFAULT  null,
   "perm_create_domain" DEFAULT  false,
   "perm_delete_domain" DEFAULT  false,
   "perm_manage_tokens" DEFAULT  false,
   "auto_policy"        DEFAULT  false,
   "allowed_subnets"    DEFAULT [ "0.0.0.0/0", "::/0" ]
'

}
create_token() {
   #--create token----
   local token_name=$1
   echo " Create token. name: $token_name"
   echo " 创建普通的 api_token。"
   if [ -z "$token_config_file" ]; then
      echo "   name: $token_name"
      local buf=$(
      curl ${opt} -X POST 'https://desec.io/api/v1/auth/tokens/' \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '{"name": "'$token_name'"}'
      )
      logs create_token "$buf"
   else
      echo "   token-config file: ${token_config_file}"
      local buf=$(
      curl ${opt} -X POST 'https://desec.io/api/v1/auth/tokens/' \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         "@${token_config_file}"
      )
      logs create_token ${token_config_file} "$buf"
   fi
   echo "$buf" | jq .
   echo " token 只会显示这一次。以后list tokens只显示id。"
   echo "   !!! 请立即 复制保存 token。!!!"
}
modify_token() {
   #--modify token----
   local token_id=$1
   local token_name=$2
   echo " Modify token. id: $token_id"
   if [ -z "$token_config_file" ]; then
      echo "   name: $token_name"
      local buf=$(
      curl ${opt} -X PUT 'https://desec.io/api/v1/auth/tokens/'${token_id}'/' \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '{"name": "'$token_name'"}'
      )
      logs modify_token "$buf"
   else
      echo "   token-config file: ${token_config_file}"
      local buf=$(
      curl ${opt} -X PUT 'https://desec.io/api/v1/auth/tokens/'${token_id}'/' \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         "@${token_config_file}"
      )
      logs modify_token ${token_config_file} "$buf"
   fi
   logs modify_token "$buf"
   echo "$buf" | jq .
}
delete_token() {
   #--delete token----
   local token_id=$1
   echo " Delete token. id: $token_id"
   local buf=$(
   curl ${opt} -X DELETE 'https://desec.io/api/v1/auth/tokens/'${token_id}'/' \
      --header "Authorization: Token ${token}"
   )
   echo ' 删除token, 成功删除返回""空(非json),失败才返回json'
   logs delete_token $token "$buf"
   if [ -z "$buf" ]; then 
      echo ' ""空'
   else
      echo " $buf"
   fi
}
list_token_policy() {
   #--list token policy----
   local token_id=$1
   echo " List token policy. token_id: $token_id"
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/auth/tokens/'${token_id}'/policies/rrsets/' \
      --header "Authorization: Token ${token}"
   )
   logs list_token_policy $token_id "$buf"
   echo "$buf" | jq .
}
create_token_policy() {
   #--create token policy----
   local token_id=$1
   local domain=$2
   local subname=$3
   local rr_type=$4
   local p_write=$5
   local policy_buf='{'
   if [ -z "$domain" -o "$domain" = "null" ]; then
      policy_buf="${policy_buf}\"domain\":null,"
   else
      policy_buf="${policy_buf}\"domain\":\"$domain\","
   fi
   if [ -z "$subname" -o "$subname" = "null" ]; then
      policy_buf="${policy_buf}\"subname\":null,"
   else
      policy_buf="${policy_buf}\"subname\":\"$subname\","
   fi
   if [ -z "$rr_type" -o "$rr_type" = "NULL" ]; then
      policy_buf="${policy_buf}\"type\":null,"
   else
      policy_buf="${policy_buf}\"type\":\"$rr_type\","
   fi
   policy_buf="${policy_buf}\"perm_write\":${p_write} }"
   echo " Create token policy. token_id: $token_id $policy_buf"
   local buf=$(
   curl ${opt} -X POST 'https://desec.io/api/v1/auth/tokens/'${token_id}'/policies/rrsets/' \
      --header "Authorization: Token ${token}" \
      --header "Content-Type: application/json" --data-binary \
      "$policy_buf"
   )
   logs create_token_policy $token_id "$buf"
   echo "$buf" | jq .
}
modify_token_policy() {
   #--create token policy----
   local token_id=$1
   local policy_id=$2
   local domain=$3
   local subname=$4
   local rr_type=$5
   local p_write=$6
   local policy_buf='{'
   if [ -z "$domain" -o "$domain" = "null" ]; then
      policy_buf="${policy_buf}\"domain\":null,"
   else
      policy_buf="${policy_buf}\"domain\":\"$domain\","
   fi
   if [ -z "$subname" -o "$subname" = "null" ]; then
      policy_buf="${policy_buf}\"subname\":null,"
   else
      policy_buf="${policy_buf}\"subname\":\"$subname\","
   fi
   if [ -z "$rr_type" -o "$rr_type" = "NULL" ]; then
      policy_buf="${policy_buf}\"type\":null,"
   else
      policy_buf="${policy_buf}\"type\":\"$rr_type\","
   fi
   policy_buf="${policy_buf}\"perm_write\":${p_write} }"
   echo " Create token policy. token_id: $token_id policy_id: $policy_id $policy_buf"
   local buf=$(
   curl ${opt} -X PUT 'https://desec.io/api/v1/auth/tokens/'${token_id}'/policies/rrsets/'${policy_id}'/' \
      --header "Authorization: Token ${token}" \
      --header "Content-Type: application/json" --data-binary \
      "$policy_buf"
   )
   logs modify_token_policy $token_id $policy_id "$buf"
   echo "$buf" | jq .
}
delete_token_policy() {
   #--delete token policy----
   local token_id=$1
   local policy_id=$2
   echo " Delete token policy. token_id: $token_id  policy_id: $policy_id"
   local buf=$(
   curl ${opt} -X DELETE 'https://desec.io/api/v1/auth/tokens/'${token_id}'/policies/rrsets/'${policy_id}'/' \
      --header "Authorization: Token ${token}"
   )
   logs delete_token_policy $token_id $policy_id "$buf"
   echo ' 删除token_policy, 成功返回""空'
   if [ -z "$buf" ]; then 
      echo ' ""空'
   else
      echo " $buf"
   fi
}
list_domains() {
   #---list domains---
   echo " List domains."
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/domains/' \
      --header "Authorization: Token ${token}"
   )
   #echo "$buf" |json_pp -f json  #正常返回,第一层是数组; 如果出错,第一层是字典;
   logs list_domains "$buf"
   #{ read num; read detail; } <  <( echo "$buf" | jq '.|length, .detail' ) #读两行,debug
   # 不加?, jq会报一个错误，无法在数组array查找 string的key;
   { read num; read detail; } <  <( echo "$buf" | jq '.|length, has("detail")?' ) #读两行
      if [ "$num" -eq 1 -a "$detail" = "true" ]; then
         echo " $buf"
         return
      fi
   echo "  count: $num"
   if [ "$DETAIL" = "yes" ]; then
      echo "$buf" | jq .
   else
      #echo "$buf" | jq '.[]|{name:.name}'
      #echo "$buf" | jq '[ foreach .[].name as $item (0; . + 1;{key: .|tostring, value:$item}) ] | from_entries'
      echo "$buf" | jq -r ' foreach .[].name as $item (0; . + 1;[ "  " + (.|tostring), $item]) |@tsv'
      #echo "$buf" | jq '.[].name'
   fi
   echo 
}
show_domain() {
   #---show domain---
   local name="$1"
   echo " show domain: $name"
   local buf=$(
   curl ${opt} -X GET 'https://desec.io/api/v1/domains/'${name}'/' \
      --header "Authorization: Token ${token}"
   )
   logs show_domains "$buf"
   echo "$buf" | jq .
   echo 
}

list_domain_stats() {
    #---list domain stats---
   local name="$1"
   echo " List domain stats DOMAIN: $name"
   local buf=$(
    curl ${opt} -X GET "https://desec.io/api/v1/domains/${name}/" \
       --header "Authorization: Token ${token}"
   )
   logs list_domain_stats $name "$buf"
   #echo "$buf" |json_pp -f json 
   echo "$buf" | jq .
}
list_rrset() {
   local name="$1"
   echo " List rrset DOMAIN: $name"
   local buf=$(
   #---list domain rrset---
   curl ${opt} -X GET "https://desec.io/api/v1/domains/${name}/rrsets/" \
      --header "Authorization: Token ${token}"
   )
   logs list_rrset $name "$buf"
   #echo "$buf" |json_pp -f json 
   echo "$buf" | jq .
}
list_zonefile() {
   local name="$1"
   echo " List zonefile DOMAIN: $name"
   local buf=$(
   #---list domain zonefile---
   curl ${opt} -X GET "https://desec.io/api/v1/domains/${name}/zonefile/" \
      --header "Authorization: Token ${token}"
   )
   #echo "$buf" |json_pp -f json 
   logs list_zonefile $name "$buf"
   echo "$buf" 
}
modify_rrset_txt_TEST() {
   #---create/modify rrset 创建/修改固定TXT(测试)----
   #此函数,程序中未使用
   curl ${opt} -X POST "https://desec.io/api/v1/domains/${name}/rrsets/" \
      --header "Authorization: Token ${token}" \
      --header "Content-Type: application/json" --data-binary \
      '{"subname": "_dnsauth", "type": "TXT", "ttl": 3600, "records": ["\"202207_test_test\""]}' | jq .
}
domain_rrset_txt() {
   local name="$2"
   #txt_name="_dnsauth"
   local txt_name="_acme-challenge"
   local txt_name="$3"
   echo " DOMAIN: $name, TXT: $txt_name"
   if [ "$1" = 'modify' ]; then
      local txt_content="202207_test_test"
      local txt_content="$4"
      echo " value: $txt_content"
      echo ' create OR modify.'
      logs modify_rrset_txt $name $txt_name $txt_content
      #---create/modify rrset---
      #  -- TXT 必须用 "\" \""--
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${txt_name}'", "type": "TXT", "ttl": 3600, "records": ["\"'${txt_content}'\""]}]' | jq .

   elif [ "$1" = 'delete' ]; then
      echo ' delete.'
      #---delete rrset----
      #  -- TXT --
      logs delete_rrset_txt $name $txt_name
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${txt_name}'", "type": "TXT", "ttl": 3600, "records": []}]' | jq .
   fi
}
domain_rrset_cname() {
   local name="$2"
   local cname_name="_acme-challenge"
   local cname_name="$3"
   echo " DOMAIN: $name, CNAME: $cname_name"
   if [ "$1" = 'modify' ]; then
      local cname_target="$4"
      echo " value: $cname_target"
      echo ' create OR modify.'
      logs modify_rrset_cname $name $cname_name $cname_target
      #---create/modify rrset---
      #  -- CNAME须以点结尾--
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${cname_name}'", "type": "CNAME", "ttl": 3600, "records": ["'${cname_target}'."]}]' | jq .

   elif [ "$1" = 'delete' ]; then
      echo ' delete.'
      logs modify_rrset_cname $name $cname_name
      #---delete rrset----
      #  -- CNAME --
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${cname_name}'", "type": "CNAME", "ttl": 3600, "records": []}]' | jq .
   fi
}
domain_rrset_type() {
   local name="$2"
   local buf_header="DOMAIN: $name, SUBDOMAIN: $subdomain_name, TYPE: $subdomain_type "
   if [ "$1" = 'modify' ]; then
      echo " CONTENT: $subdomain_value "
      echo ' create OR modify.'
      #---create/modify rrset---
      local buf=$(
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${subdomain_name}'", "type": "'${subdomain_type}'", "ttl": 3600, "records": ["'${subdomain_value}'"]}]'
      )
      local buf2=$(
         echo "$buf_header" 
         echo "$buf" 
         echo '更新 IP:'
         echo "  curl -x \"\" --user ${subdomain_name}.${name}:___token___ \"https://update.dedyn.io/?myipv4=preserve&myipv6=2001::3\""
      )
      logs modify_rrset "$buf2"
      echo "$buf2" 
      echo "$buf" | jq .

   elif [ "$1" = 'delete' ]; then
      echo ' delete.'
      #---delete rrset----
      local buf=$(
      curl ${opt} -X PUT "https://desec.io/api/v1/domains/${name}/rrsets/" \
         --header "Authorization: Token ${token}" \
         --header "Content-Type: application/json" --data-binary \
         '[{"subname": "'${subdomain_name}'", "type": "'${subdomain_type}'", "ttl": 3600, "records": []}]'
      )
      local buf2=$(
         echo "$buf_header" 
         echo "$buf" 
      )
      logs delete_rrset "$buf2"
      echo "$buf2" 
      echo "$buf" | jq .
   fi
}
logs() {
   local log_file=${selfpath}/log.history.log
   #echo $(/bin/date '+%F_%T%z_%w_%a') "$*" >> $log_file
   echo $(/bin/date '+%F_%T%z') "$*" >> $log_file
   echo >> $log_file
   if [ -f "$log_file" ]; then
      local filemode=$(ls -l $log_file |cut -d' ' -f1)
      if [ "$filemode" != '-rw-------' ]; then
         chmod 600 $log_file
      fi
   fi
}

usage() {  # usage
    local S=$( echo "$0" |sed 's/./ /g') #获取 $0 相同长度的 "空格"
    echo -e " --------------------------"
    echo -e " Version: $VERSION  Date: $VERSION_DATE"
    echo -e " Usage: $0 <command> ... [parameters ...]"
    echo -e " Commands:"
  if [ -n "$1" -a "$1" = "all" ]; then
    echo -e "   --login           Get a New temporary login token, Low authority, Not used"
    echo -e "                     temp login_token ,valid for 7 days, expire after 1 hour of inactivity. Low authority."
    echo -e "                     Can update IP address, create/modify/del rrset(cname,txt);"
    echo -e "                     Can not list domain, list stats, list rrset, list zonefile, list token."
    echo -e "   --logout          logout token/destroy token/logoff token (Will not logoff admin api_token)"
    echo -e "                     (Will logoff normal api_token)"
  fi
    echo -e "      #####If the --api or --admin parameter is not specified, \"temporary logic_token\" will be used by default#####"
    echo -e "   --accinfo         show account_info."
    echo -e "   --tokens          list all tokens."
    echo -e "   --token-conf help Show token-config file Examples & Notes."
    echo -e "   --create-token    create token. '-s token_name [--token-conf <file>]'"
    echo -e "   --show-token      show token.   '-v token_id'"
    echo -e "   --modify-token    modify token. '-v token_id -s token_name [--token-conf <file>]'"
    echo -e "   --delete-token    delete token. '-v token_id'"
    echo -e "   --token-policy    list token all policies. '-v token_id'"
    echo -e "   --create-policy   create token policy. '-v token_id [-d domain] [-s subname] [-t type] [--write]'"
    echo -e "   --modify-policy   modify token policy. '-v token_id -p policy_id [-d domain] [-s subname] [-t type] [--write]'"
    echo -e "   --delete-policy   delete token policy. '-v token_id -p policy_id'"
    echo -e "   --domains         list all domains.'"
    echo -e "   --show-domain     show domain.          '-d <domain>'"
    echo -e "   --zones           list domain zonefile. '-d <domain>'"
    echo -e "   --rrsets          list domain rrset.    '-d <domain>'"
    echo -e "   --stats           list domain stats.    '-d <domain>'"
    echo -e "   --cname1          create/modify rrset '-d <domain> -s <CNAME_name> -v value'"
    echo -e "   --cname2          delete rrset        '-d <domain> -s <CNAME_name>'"
    echo -e "   --txt1            create/modify rrset '-d <domain> -s <TXT_name>  -v value'"
    echo -e "   --txt2            delete rrset        '-d <domain> -s <TXT_name>'"
    echo -e "   -u, --update      update IPs.         '-d <subdomain/domain> --ipv4 <ip> --ipv6 <ip>'"
    echo -e "                     update ipv4/ipv6 for nnn.<domain>, will create subname \"nnn\" type A/AAAA."
    echo -e "    ##### CNAME, TXT can use '\"rrset\" operation for create/modify/delete #####"
    echo -e "   --rrset1          create/modify rrset, specify type '-d <domain> -s <subname> -t A -v 127.0.0.1'"
    echo -e "   --rrset2          delete rrset, specify type        '-d <domain> -s <subname> -t A'"
    echo -e "   --myipv4, --myipv6"
    echo -e "                     Obtain your external IPv4/IPv6 addresses through external websites."
    echo -e "   --localipv4, --localipv6"
    echo -e "                     Obtain the IPv4/IPv6 addresses of the local machine through the local network device."
    echo -e "   -h, --help        Show this help message."
    echo -e "   -V, --version     Show version info."
#    echo
    echo -e " Parameters:"
    echo -e "   -a, --api                USE api_token."
    echo -e "                            etc:  $0 -a --domains (list all domains)"
    echo -e "   --admin                  USE admin_token. High authority."
    echo -e "   -d, --domain <domain>    Specify domain.           \"test.dedyn.io\""
    echo -e "   -s, --subname <subname>  Specify the subname Excluding main domain. \"mysub\""
    echo -e "   -t, --type <type>        type of rrset."
    echo -e "      <type>(must be upper case) A, AAAA, AFSDB, APL, CAA, CDNSKEY, CDS, CERT, CNAME, DHCID, DNAME, DNSKEY, "
    echo -e "           DLV, DS, EUI48, EUI64, HINFO, HTTPS, KX, L32, L64, LOC, LP, MX, NAPTR, NID, NS, "
    echo -e "           OPENPGPKEY, PTR, RP, SMIMEA, SPF, SRV, SSHFP, SVCB, TLSA, TXT, URI"
    echo -e "   -d, -s, -t               use with token_policy, If not set:{domain, subname, type} is null"
    echo -e "   -v,--value <value>       rrset value. with token operation:token_id"
    echo -e "   -p,--policy <policy_id>  token_policy_id."
    echo -e "   --token-conf <file>      Set token-config filename."
    echo -e "   --write                  set {perm_write:true}, otherwise{perm_write:false}"
    echo -e "   --ipv4 <ipv4>            ipv4 address. \"127.0.0.2\""
    echo -e "   --ipv6 <ipv6>            ipv6 address. \"2001::234\""
    echo -e "   -D, --verbose            show curl progress. For list tokens/domains, show more."
    echo -e "   --proxy socks5h://usr:pwd@127.0.0.1:1080     curl proxy set."
    echo -e " Examples:"
    echo -e "   $0 --token-conf help | tee ./test.txt"
    echo -e "   $0 --admin --modify-token -v "5cxxxxxxxxxdc" -s any -token-conf ./test.txt"
    echo -e "   $0 --admin --modify-policy -v e0xxxxxxxxxc2 -p 33xxxxxx88 -d test.dedyn.io -s nnn -t AAAA --write"
    echo -e "   $0 -a --cname1 -d test.dedyn.io -s nnn -v test_cname_txt"
    echo -e "   $0 -a --rrset1 -d xxx.dedyn.io -s nnn -t AAAA -v 2001::3"
    echo -e "   $0 -a --update -d nnn.test.dedyn.io --ipv6 2001::5"
    echo -e "   $0 --localipv6"
    echo -e "   $0 -a --domains --proxy http://usr:pwd@127.0.0.1:8080"
    echo -e " Documentation:"
    echo -e "   [dedyn_desec_simple_tool](https://gitee.com/osnosn/dedyn_desec_simple_tool)"
    echo -e "   [deSEC.io DNS API](https://desec.readthedocs.io/)"
    echo -e " -------------------------"
    exit
}
token_config_file=''
domain_name=''
subdomain_name=''
subdomain_value=''
subdomain_type=''
policy_id=''
perm_write='false'
curl_proxy=''
DETAIL=''
CMD=''
[ -z "$1" ] && usage && exit 1  #无参数
OPTS=$(getopt -a -o "ad:hup:s:t:v:VD" \
   -l "login,logout,tokens,token-conf:,show-token,token-policy,create-policy,modify-policy,delete-policy,create-token,modify-token,delete-token,accinfo,domains,show-domain,zones,rrsets,stats,cname1,cname2,txt1,txt2,update,rrset1,rrset2,domain:,subname:,value:,type:,ipv4:,ipv6:,admin,api,proxy:,policy:,myipv4,myipv6,localipv4,localipv6,write,verbose,version,help" \
   -n " $0" -- "$@")
if [ $? != 0 ]; then
   echo ' getopt err!'
   echo " $0 -h    For Help"
   exit 1
fi
#echo "$OPTS"   #debug
eval set -- "$OPTS"   #重置命令行参数
while true; do
   case $1 in
      --login) CMD='login_token'
         ;;
      --logout) # logout token/destroy token/注销token
         CMD='logout_token'
         ;;
      --tokens) CMD='list_tokens'
         ;;
      --token-conf)
         if [ "$2" = "help" ]; then
            CMD='show_token_conf'
         else 
            token_config_file=$2
         fi
         shift
         ;;
      --show-token) CMD='show_token'
         ;;
      --token-policy) CMD='list_token_policy'
         ;;
      --create-policy) CMD='create_token_policy'
         ;;
      --modify-policy) CMD='modify_token_policy'
         ;;
      --delete-policy) CMD='delete_token_policy'
         ;;
      --create-token) CMD='create_token'
         ;;
      --modify-token) CMD='modify_token'
         ;;
      --delete-token) CMD='delete_token'
         ;;
      --accinfo) CMD='account_info'
         ;;
      --domains) CMD='list_domains'
         ;;
      --show-domain) CMD='show_domain'
         ;;
      --zones) CMD='list_zonefile'
         ;;
      --rrsets) CMD='list_rrset'
         ;;
      --stats) CMD='list_domain_stats'
         ;;
      --cname1) # create/modify rrset CNAME
         CMD='domain_rrset_cname_add'
         ;;
      --cname2) # delete rrset CNAME
         CMD='domain_rrset_cname_del'
         ;;
      --txt1) # create/modify rrset TXT
         CMD='domain_rrset_txt_add'
         ;;
      --txt2) # delete rrset TXT
         CMD='domain_rrset_txt_del'
         ;;
      -u|--update) # update IPs
         CMD='update_ip'
         ;;
      --rrset1)  # create/modify rrset TYPE
         CMD='domain_rrset_type_add'
         ;;
      --rrset2)  # delete rrset TYPE
         CMD='domain_rrset_type_del'
         ;;
      -a|--api)  # use api_token
         token=$api_token
         ;;
      --admin)  # use api_token
         token=$admin_token
         ;;
      -d|--domain)  # domain_name
         domain_name="$2"
         shift
         ;;
      -t|--type)  # subdomain_type
         subdomain_type=$2
         subdomain_type=${subdomain_type^^}  #全部大写
         shift
         ;;
      -s|--subname)  # subdomain_name
         subdomain_name=$2
         shift
         ;;
      -v|--value)  # subdomain_value
         subdomain_value=$2
         shift
         ;;
      -p|--policy)  # token_policy_id
         policy_id=$2
         shift
         ;;
      --write)  # token_policy, perm_write
         perm_write='true'
         ;;
      --ipv4)
         ipv4_value=$2
         shift
         ;;
      --ipv6)
         ipv6_value=$2
         shift
         ;;
      --proxy)
         curl_proxy=$2
         shift
         ;;
      --myipv4)
         CMD='myipv4'
         ;;
      --myipv6)
         CMD='myipv6'
         ;;
      --localipv4)
         CMD='localipv4'
         ;;
      --localipv6)
         CMD='localipv6'
         ;;
      -D|--verbose)
         opt=''
         DETAIL='yes'
         ;;
      -V|--version)  # help
         echo -e " Version: $VERSION  Date: $VERSION_DATE"
         exit 1
         ;;
      -h)  # help
         usage
         exit 1
         ;;
      --help)  # help
         usage all
         exit 1
         ;;
      --)
         shift
         break  #break 之前要shift
         ;;
      *)
         echo " Unkown argument: $1"
         echo " $0 -h    For Help"
         exit 1
         ;;
    esac
    shift  #统一"shift"一个参数
done
# 处理proxy
if [ -n "$curl_proxy" ]; then
   opt="$opt -x $curl_proxy"   #有代理
fi
# 处理除选项外的参数
if [ -n "$1" ]; then
   #多余的参数
   echo " Unkown argument: $1"
   echo " $0 -h    For Help"
   exit 1
fi
if [ -z "$CMD" ]; then  #没有指定命令
   echo " $0 $OPTS"   #debug
   echo ' No Command. Nothing to do.'
   echo " $0 -h    For Help"
fi
case $CMD in
   login_token)
      login_token
      ;;
   logout_token)  # logout token/destroy token/注销token
      logout_token
      ;;
   account_info)  # account_info
      account_info
      ;;
   list_tokens)
      list_tokens
      ;;
   show_token_conf)
      show_token_conf
      ;;
   show_token)
      [ -z "$subdomain_value" ] && echo -e " -v <token_id> 缺失\n $0 -h    For Help" && exit 1
      show_token $subdomain_value
      ;;
   list_token_policy)
      [ -z "$subdomain_value" ] && echo -e " -v <token_id> 缺失\n $0 -h    For Help" && exit 1
      list_token_policy $subdomain_value
      ;;
   create_token_policy)
      [ -z "$subdomain_value" ] && echo -e " -v <token_id> [-d <domain>] [-s <subname>] [-t <type>] [--write] 缺失\n $0 -h    For Help" && exit 1
      create_token_policy "$subdomain_value" "$domain_name" "$subdomain_name" "$subdomain_type" "$perm_write"
      ;;
   modify_token_policy)
      [ -z "$subdomain_value" -o -z "$policy_id" ] && echo -e " -v <token_id> -p <policy_id> [-d <domain>] [-s <subname>] [-t <type>] [--write] 缺失\n $0 -h    For Help" && exit 1
      modify_token_policy "$subdomain_value" "$policy_id" "$domain_name" "$subdomain_name" "$subdomain_type" "$perm_write"
      ;;
   delete_token_policy)
      [ -z "$subdomain_value" -o -z "$policy_id" ] && echo -e " -v <token_id> -p <policy_id> 缺失\n $0 -h    For Help" && exit 1
      delete_token_policy $subdomain_value $policy_id
      ;;
   create_token)
      [ -z "$subdomain_name" ] && echo -e " -s <token_name> [--token-conf <file>] 缺失\n $0 -h    For Help" && exit 1
      create_token $subdomain_name
      ;;
   modify_token)
      [ -z "$subdomain_name" -o -z "$subdomain_value" ] && \
         echo -e " -v <token_id> -s <token_name> [--token-conf <file>] 缺失\n $0 -h    For Help" && exit 1
      modify_token $subdomain_value $subdomain_name
      ;;
   delete_token)
      [ -z "$subdomain_value" ] && echo -e " -v <token_id> 缺失\n $0 -h    For Help" && exit 1
      delete_token $subdomain_value
      ;;
   list_zonefile)
      [ -z "$domain_name" ] && echo -e " -d <domain> 缺失"
      [ ${#domain_name} -le 9 ] && echo -e " 域名不正确: $domain_name\n $0 -h    For Help" && exit 1
      list_zonefile "$domain_name"
      ;;
   list_rrset)
      [ -z "$domain_name" ] && echo -e " -d <domain> 缺失"
      [ ${#domain_name} -le 9 ] && echo -e " 域名不正确: $domain_name\n $0 -h    For Help" && exit 1
      list_rrset "$domain_name"
      ;;
   domain_rrset_cname_add)  # create/modify rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" -o -z "$subdomain_value" ] && \
         echo -e " -d <domain> -s <CNAME> -v <value> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_cname modify "$domain_name" "$subdomain_name" "$subdomain_value"
      ;;
   domain_rrset_cname_del)  # delete rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" ] && echo -e " -d <domain> -s <CNAME> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_cname delete "$domain_name" "$subdomain_name"
      ;;
   list_domains)  # list_domains
      list_domains
      ;;
   show_domain)
      [ -z "$domain_name" ] && echo -e " -d <domain> 缺失\n $0 -h    For Help" && exit 1
      show_domain $domain_name
      ;;
   list_domain_stats)  # list_domain_stats
      [ -z "$domain_name" ] && echo -e " -d <domain> 缺失"
      [ ${#domain_name} -le 9 ] && echo -e " 域名不正确: $domain_name\n $0 -h    For Help" && exit 1
      list_domain_stats "$domain_name"
      ;;
   domain_rrset_txt_add)  # create/modify rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" -o -z "$subdomain_value" ] && \
         echo -e " -d <domain> -s <TXT> -v <value> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_txt modify "$domain_name" "$subdomain_name" "$subdomain_value"
      ;;
   domain_rrset_txt_del)  # delete rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" ] && echo -e " -d <domain> -s <TXT> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_txt delete "$domain_name" "$subdomain_name"
      ;;
   domain_rrset_type_add)  # create/modify rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" -o -z "$subdomain_type" -o -z "$subdomain_value" ] && \
         echo -e " -d <domain> -t <type> -s <TXT> -v <value> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_type modify "$domain_name"
      ;;
   domain_rrset_type_del)  # delete rrset CNAME
      [ -z "$domain_name" -o -z "$subdomain_name" -o -z "$subdomain_type" ] && \
         echo -e " -d <domain> -t <type> -s <TXT> 缺失\n $0 -h    For Help" && exit 1
      domain_rrset_type delete "$domain_name"
      ;;
   update_ip)  # delete rrset CNAME
      [ -z "$domain_name" ] && echo -e " -d <domain> 缺失\n $0 -h    For Help" && exit 1
      [ -z "$ipv4_value" -a -z "$ipv6_value" ] && echo -e " --ipv4 <ip> 或 --ipv6 <ip> 缺失\n $0 -h    For Help" && exit 1
      [ -z "$ipv4_value" ] && ipv4_value="preserve"
      [ -z "$ipv6_value" ] && ipv6_value="preserve"
      update_ddns "$domain_name" "$ipv4_value" "$ipv6_value"
      ;;
   myipv4)
      curl ${opt} https://checkipv4.dedyn.io/
      echo 
      ;;
   myipv6)
      curl ${opt} https://checkipv6.dedyn.io/
      echo 
      ;;
   localipv4)
      ipv4=$(/bin/ip -4 -o addr show|sed -nr 's#.+? +inet ([0-9.]+)/[0-9]+ brd [0-9./]+ scope global .*#\1#p')
      ipv4=$(echo -n $ipv4|sed -e 's/^\s*//' -e 's/\s*$//g')   #trim()
      echo $ipv4
      ;;
   localipv6)
      #ipv6=$(/bin/ip -6 -o addr show |/bin/grep -v deprecated|/bin/grep ' inet6 [^f:]'|/bin/sed -nr 's#^.+? +inet6 ([a-f0-9:]+)/.+? scope global .*? valid_lft ([0-9]+sec) .*#\2 \1#p'|/bin/grep 'ff:fe'|/usr/bin/sort -nr|/usr/bin/head -n1|/usr/bin/cut -d' ' -f2)  # eui64
      ipv6=$(/bin/ip -6 -o addr show |/bin/grep -v deprecated|/bin/grep ' inet6 [^f:]'|/bin/sed -nr 's#^.+? +inet6 ([a-f0-9:]+)/.+? scope global .*? valid_lft ([0-9]+sec) .*#\2 \1#p'|/usr/bin/sort -nr|/usr/bin/head -n1|/usr/bin/cut -d' ' -f2)
      echo $ipv6
      ;;
   ?)
      echo 'Unkown CMD.'
      echo " $0 -h    For Help"
      exit 1
      ;;
esac

