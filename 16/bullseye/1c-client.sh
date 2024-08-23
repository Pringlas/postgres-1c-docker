#!/bin/bash

# Функция для получения тикета
ticket_request() {
    local url="$1"
    local login="$2"
    local password="$3"
    
    response=$(curl -s -X POST "${login_url}/rest/public/ticket/get" \
        -u "$login:$password" \
        -H "Content-Type: application/json" \
        -d "{\"login\":\"${login}\",\"password\":\"${password}\",\"serviceNick\":\"${url}\"}" \
        -c cookies.txt -b cookies.txt)

    echo $(echo "$response" | jq -r '.ticket')
}

# Функция для выполнения запроса к сайту https://releases.1c.ru
releases_request() {
    local path="$1"
    local authorized="$2"
    
    if [ "$authorized" = true ]; then
        ticket=$(ticket_request "$releases_url" "$user" "$password")
        url="${login_url}/ticket/auth?token=${ticket}"
    else
        url="${releases_url}${path}"
    fi

    response=$(curl -s -L -u "$user:$password" -c cookies.txt -b cookies.txt "$url")
    echo "$response"
}

# Функция для получения URL для загрузки
get_download_url() {
    releases_request "/" true > /dev/null
    response=$(releases_request "$1" false)

    # Извлечение URL для загрузки
    download_url=$(echo "$response" | xmllint --html --xpath '(//div[@class="downloadDist"]/a/@href)[1]' - 2>/dev/null | grep -oP 'https?://[^"]+')
    echo "$download_url"
}

# Основной код
releases_url="https://releases.1c.ru"
login_url="https://login.1c.ru"

# Удаляем файл куки, если он существует
rm -f cookies.txt

while getopts "u:p:f:" opt; do
    case $opt in
        u) user="$OPTARG" ;;
        p) password="$OPTARG" ;;
        f) file="$OPTARG" ;;
        *) echo "Неверный параметр"; exit 1 ;;
    esac
done
shift $((OPTIND -1))

path="$1"

# Проверка на наличие незаполненных параметров
if [ -z "$user" ] || [ -z "$password" ]; then
    echo "Ошибка: Необходимо указать имя пользователя (-u) и пароль (-p)."
    exit 1
fi

if [ -z "$path" ]; then
    echo "Ошибка: Необходимо указать путь на сервере."
    exit 1
fi

if [ -z "$file" ]; then
    response=$(releases_request "$path" true)
    if [ $? -ne 0 ]; then
        echo "Ошибка при выполнении запроса"
        exit 1
    fi
    echo "$response"
else
    url=$(get_download_url "$path")
    response=$(curl -L -u "$user:$password" -b cookies.txt -o "$file" "$url")
    if [ $? -ne 0 ]; then
        echo "Ошибка при загрузке файла"
        exit 1
    fi
fi

# Удаляем файл куки после завершения работы
rm -f cookies.txt