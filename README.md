# dedyn_desec_simple_tool

### desec_ddns_RRset.sh
* A client tool for dedyn.io, desec.io.  
* Just a bash script file.  

### Requirements
* `apt install jq curl til Linux coreutilities`  

### Installation
* Suitable for Linux terminals such as debian/ubuntu.  
* Copy `desic_dns_RRset.sh` to local directory.  
* `chmod +x desec_ddns_RRset.sh`  
* Run `./desec_ddns_RRset.sh -h` View Help.  

### Usage
* Modify the first few lines of `desec_ddns_RRset.sh`   
  ```
  #DDNS open source/desic.io/register account/need to receive email first, click on the activation link to set password/suggest setting 2FA to ensure account security/
  EMAIL_USR='xxx@email'      #desec.io USERNAME
  EMAIL_PWD='xxxxxxxxxx'     #PASSWORD

  # api_token with high authority
  admin_token='ac------------------------tH'   #main_token
  # Long term valid api_token. If it is logged out, you need to log in to desic.io to create a new api_token, and then update the token in the ddns script
  # api_token without perm_create_domain, perm_delete_domain, perm_manage_tokens; Cannot operate on list_tokens, show_account_info. Other operation is OK.
  api_token='yy------------------------RR' #update_token,(No manage tokens,No create/delete domains; Can create rrset records.)
  ```
* EMAIL_USR, EMAIL_PWD  Not necessary to set it.   
  admin_token   Set as required.   
  api_token     Must be set.   
* `./desec_ddns_RRset.sh -h`  View help.  
  ```
   --------------------------
   Version: v1.1  Date: 2025-09
   Usage: ./desec_ddns_RRset.sh <command> ... [parameters ...]
   Commands:
        #####If the --api or --admin parameter is not specified, "temporary logic_token" will be used by default#####
     --accinfo         show account_info.
     --tokens          list all tokens.
     --token-conf help Show token-config file Examples & Notes.
     --create-token    create token. '-s token_name [--token-conf <file>]'
     --show-token      show token.   '-v token_id'
     --modify-token    modify token. '-v token_id -s token_name [--token-conf <file>]'
     --delete-token    delete token. '-v token_id'
     --token-policy    list token all policies. '-v token_id'
     --create-policy   create token policy. '-v token_id [-d domain] [-s subname] [-t type] [--write]'
     --modify-policy   modify token policy. '-v token_id -p policy_id [-d domain] [-s subname] [-t type] [--write]'
     --delete-policy   delete token policy. '-v token_id -p policy_id'
     --domains         list all domains.'
     --show-domain     show domain.          '-d <domain>'
     --zones           list domain zonefile. '-d <domain>'
     --rrsets          list domain rrset.    '-d <domain>'
     --stats           list domain stats.    '-d <domain>'
     --cname1          create/modify rrset '-d <domain> -s <CNAME_name> -v value'
     --cname2          delete rrset        '-d <domain> -s <CNAME_name>'
     --txt1            create/modify rrset '-d <domain> -s <TXT_name>  -v value'
     --txt2            delete rrset        '-d <domain> -s <TXT_name>'
     -u, --update      update IPs.         '-d <subdomain/domain> --ipv4 <ip> --ipv6 <ip>'
                       update ipv4/ipv6 for nnn.<domain>, will create subname "nnn" type A/AAAA.
      ##### CNAME, TXT can use '"rrset" operation for create/modify/delete #####
     --rrset1          create/modify rrset, specify type '-d <domain> -s <subname> -t A -v 127.0.0.1'
     --rrset2          delete rrset, specify type        '-d <domain> -s <subname> -t A'
     --myipv4, --myipv6
                       Obtain your external IPv4/IPv6 addresses through external websites.
     --localipv4, --localipv6
                       Obtain the IPv4/IPv6 addresses of the local machine through the local network device.
     -h, --help        Show this help message.
     -V, --version     Show version info.
   Parameters:
     -a, --api                USE api_token.
                              etc:  ./desec_ddns_RRset.sh -a --domains (list all domains)
     --admin                  USE admin_token. High authority.
     -d, --domain <domain>    Specify domain.           "test.dedyn.io"
     -s, --subname <subname>  Specify the subname Excluding main domain. "mysub"
     -t, --type <type>        type of rrset.
        <type>(must be upper case) A, AAAA, AFSDB, APL, CAA, CDNSKEY, CDS, CERT, CNAME, DHCID, DNAME, DNSKEY, 
             DLV, DS, EUI48, EUI64, HINFO, HTTPS, KX, L32, L64, LOC, LP, MX, NAPTR, NID, NS, 
             OPENPGPKEY, PTR, RP, SMIMEA, SPF, SRV, SSHFP, SVCB, TLSA, TXT, URI
     -d, -s, -t               use with token_policy, If not set:{domain, subname, type} is null
     -v,--value <value>       rrset value. with token operation:token_id
     -p,--policy <policy_id>  token_policy_id.
     --token-conf <file>      Set token-config filename.
     --write                  set {perm_write:true}, otherwise{perm_write:false}
     --ipv4 <ipv4>            ipv4 address. "127.0.0.2"
     --ipv6 <ipv6>            ipv6 address. "2001::234"
     -D, --verbose            show curl progress. For list tokens/domains, show more.
     --proxy socks5h://usr:pwd@127.0.0.1:1080     curl proxy set.
   Examples:
     ./desec_ddns_RRset.sh --token-conf help | tee ./test.txt
     ./desec_ddns_RRset.sh --admin --modify-token -v 5cxxxxxxxxxdc -s any -token-conf ./test.txt
     ./desec_ddns_RRset.sh --admin --modify-policy -v e0xxxxxxxxxc2 -p 33xxxxxx88 -d test.dedyn.io -s nnn -t AAAA --write
     ./desec_ddns_RRset.sh -a --cname1 -d test.dedyn.io -s nnn -v test_cname_txt
     ./desec_ddns_RRset.sh -a --rrset1 -d xxx.dedyn.io -s nnn -t AAAA -v 2001::3
     ./desec_ddns_RRset.sh -a --update -d nnn.test.dedyn.io --ipv6 2001::5
     ./desec_ddns_RRset.sh --localipv6
     ./desec_ddns_RRset.sh -a --domains --proxy http://usr:pwd@127.0.0.1:8080
   Documentation:
     [dedyn_desec_simple_tool](https://gitee.com/osnosn/dedyn_desec_simple_tool)
     [deSEC.io DNS API](https://desec.readthedocs.io/)
   -------------------------
  ```
* desec.io api DOC: [deSEC.io DNS API](https://desec.readthedocs.io/)  


### Other similar tools
* [s-hamann/desec-dns](https://github.com/s-hamann/desec-dns), In debian system.   
  In releases, find `desec_dns-1.3.0.tar.gz` and download it, then unzip it.  
  Run `python3 -m desec --help`   

### Last modified
* 2025-09

