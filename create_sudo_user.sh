#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root (sudo)"
   exit 1
fi
read -p "Введите имя нового пользователя: " username
if id "$username" >/dev/null 2>&1; then
    echo "Пользователь $username уже существует!"
    exit 1
fi
read -s -p "Введите пароль для $username: " password
echo
read -s -p "Подтвердите пароль: " password_confirm
echo
if [ "$password" != "$password_confirm" ]; then
    echo "Пароли не совпадают!"
    exit 1
fi
useradd -m -s /bin/bash "$username"
echo "$username:$password" | chpasswd
usermod -aG sudo "$username"
if [ $? -eq 0 ]; then
    echo "Пользователь $username успешно создан и добавлен в группу sudo!"
    echo "Теперь $username имеет права root через sudo."
else
    echo "Произошла ошибка при создании пользователя."
    exit 1
fi
