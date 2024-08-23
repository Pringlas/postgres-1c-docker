#!/bin/bash

# Проверка на наличие необходимых параметров
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ITS_USER> <ITS_PASSWORD>"
    exit 1
fi

# Установите переменные
ITS_USER="$1"
ITS_PASSWORD="$2"
POSTGRES_VERSIONS=("14" "15" "16")
DEBIAN_VERSIONS=("bullseye" "bookworm")
DOCKER_IMAGE_PREFIX="postgresql-1c"

# Функция для проверки соединения с PostgreSQL
check_postgres_connection() {
    local container_name=$1
    local retries=5
    local wait_time=5

    sleep $wait_time
    for ((i=0; i<retries; i++)); do
        if docker exec "$container_name" pg_isready; then
            echo "PostgreSQL is ready in container $container_name."
            return 0
        fi
        echo "Waiting for PostgreSQL to be ready in container $container_name..."
        sleep $wait_time
    done

    echo "PostgreSQL is not ready in container $container_name."
    return 1
}

# Основной цикл по версиям PostgreSQL и Debian
for version in "${POSTGRES_VERSIONS[@]}"; do
    for debian_version in "${DEBIAN_VERSIONS[@]}"; do
        echo "Building Docker image for PostgreSQL $version on Debian $debian_version..."

        # Путь к Dockerfile
        dockerfile_path="./$version/$debian_version/Dockerfile"

        # Собрать образ с передачей переменных среды
        docker build -q --build-arg ITS_USER="$ITS_USER" --build-arg ITS_PASSWORD="$ITS_PASSWORD" -t "${DOCKER_IMAGE_PREFIX}:${version}-${debian_version}" -f "$dockerfile_path" "./$version/$debian_version"

        # Запустить контейнер
        container_name="postgres_${version}_${debian_version}"
        docker run -e POSTGRES_PASSWORD=123456 --name "$container_name" -d "${DOCKER_IMAGE_PREFIX}:${version}-${debian_version}"

        # Проверить соединение с PostgreSQL
        if check_postgres_connection "$container_name"; then
            echo "Successfully connected to PostgreSQL in container $container_name."
        else
            echo "Failed to connect to PostgreSQL in container $container_name."
        fi

        # Остановить и удалить контейнер
        echo "Stopping and removing container $container_name..."
        docker stop "$container_name"
        docker rm "$container_name"

        # Удалить образ
        echo "Removing Docker image ${DOCKER_IMAGE_PREFIX}:${version}-${debian_version}..."
        docker rmi "${DOCKER_IMAGE_PREFIX}:${version}-${debian_version}"
    done
done

echo "All tests completed."