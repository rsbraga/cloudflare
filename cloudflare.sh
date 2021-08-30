#!/bin/bash

# cloudflare API integration
# dev:rafael.braga@f1commerce.com

# access
xAuthEmail=${user_email}
xAuthKey=${cloudflare_token}






[[ -z $1 || $1 == '--help' ]] && {
    echo "
Ferramenta da F1 para integração com a clouflare

Opções [parâmetros]:
    -a --add [type]         inserir novo registro na zona DNS (A, CNAME, TXT, etc)
    -c --content [host]     conteúdo a ser inserido no registro (host de hospedagem)
    -d --del                remove registro DNS da zona definida em --zone
    -l --list               listar registros da zona definida em --zone
    -n --name [subdomain]   nome do resgistro a ser inserido (subdomínio)
    -p --proxy              define o proxy como ativado (CDN cloudflare)
    -z --zone [domain.com]  define o domínio registrado

Uso:
cloudflare --zone [domain.com] --new [type] --name [subdomain] --content [host] --proxy
"
exit 1

}





function getzoneId {
# obter a ID da zona de DNS
    [[ -z $zoneName ]] && { echo 'Erro: Faltou domínio [domain.com]' ; exit 1 ; }
    
    zoneId=$( curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zoneName" \
    -H "X-Auth-Email: $xAuthEmail" \
    -H "X-Auth-Key: $xAuthKey" \
    -H "Content-Type:application/json" \
    | jq -c '.result[0].id' | sed 's/\"//g' )
}





function getRecordId {
    # verificações
    [[ -z $zoneName ]] && { echo 'Erro: Faltou domínio' ; exit 1 ; }
    [[ -z $record ]] && { echo 'Erro: Faltou nome do registro' ; exit 1 ; }

    getzoneId
    
    recordId=$( curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?per_page=1000&name=$record.$zoneName" \
    -H "X-Auth-Email: $xAuthEmail" \
    -H "X-Auth-Key: $xAuthKey" \
    -H "Content-Type:application/json" | jq '.result[0].id' | sed 's/\"//g' )
}





function zoneList {
    # verificações
    [[ -z $zoneName ]] && { echo 'Erro: Faltou domínio' ; exit 1 ; }
    # echo ${zoneName:?falta nome da zona}

    getzoneId

    echo "List records in $zoneName - $zoneId"

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?per_page=1000&match=any" \
    -H "X-Auth-Email: $xAuthEmail" \
    -H "X-Auth-Key: $xAuthKey" \
    -H "Content-Type:application/json" \
    | jq -M -r '.result[] | "\(.name) - \(.type) - \(.content)"'
}







function add {
    # verificações
    [[ -z $zoneName ]] && { echo 'Erro: Faltou domínio' ; exit 1 ; }
    [[ -z $rName ]] && { echo 'Erro: Faltou nome do registro' ; exit 1 ; }
    [[ -z $rContent ]] && { echo 'Erro: Faltou conteúdo' ; exit 1 ; }
    [[ -z $rType ]] && { echo 'Erro: Faltou o tipo do registro (A|CNAME|TXT)' ; exit 1 ; }
    [[ ${rType^^} != @(A|AAAA|CNAME|HTTPS|TXT|SRV|LOC|MX|NS|SPF|CERT|DNSKEY|DS|NAPTR|SMIMEA|SSHFP|SVCB|TLSA|URI) ]] && { 
        echo -e "Invalid TYPE - Use only: (A|AAAA|CNAME|HTTPS|TXT|SRV|LOC|MX|NS|SPF|CERT|DNSKEY|DS|NAPTR|SMIMEA|SSHFP|SVCB|TLSA|URI)" ; exit 1 ; }

    getzoneId

    echo "Insert new record in $zoneName - $zoneId"

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" \
    -H "X-Auth-Email: $xAuthEmail" \
    -H "X-Auth-Key: $xAuthKey" \
    -H "Content-Type:application/json" \
    --data "{\"type\":\"${rType^^}\",\"name\":\"$rName\",\"content\":\"$rContent\",\"proxied\":${rProxy:-false}}" \
    | jq
}





function del {
    # verificações
    [[ -z $zoneName ]] && { echo 'Erro: Faltou domínio' ; exit 1 ; }
    [[ -z $record ]] && { echo 'Erro: Faltou nome do registro' ; exit 1 ; }

    getzoneId
    getRecordId

    echo "Delete $record in $zoneName"

    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId" \
    -H "X-Auth-Email: $xAuthEmail" \
    -H "X-Auth-Key: $xAuthKey" \
    -H "Content-Type:application/json" \
    | jq
}




# read options
while [[ $@ ]] ; do
    case $1 in
        '-a' | '--add') addRecord=true ; rType=$2 ; shift 2 ;;
        '-c' | '--content') rContent=$2 ; shift 2 ;;
        '-d' | '--del') delRecord=true ; shift ;;
        '-l' | '--list') listZone=true ; shift ;;
        '-n' | '--name') rName=$2 ; shift 2  ;;
        '-p' | '--proxy') rProxy=true ; shift 1 ;;
        '-r' | '--record') record=$2 ; shift 2 ;;
        '-z' | '--zone') zoneName=$2 ; shift 2  ;;

        *) echo "Invalid option: $1 " ; exit 1 ;; 
    esac
done


# exec
[[ $addRecord == 'true' ]] && { add $zoneName ; }
[[ $delRecord == 'true' ]] && { del $record $zoneName ; }
[[ $listZone == 'true' ]] && { zoneList ; }
