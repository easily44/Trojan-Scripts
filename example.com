server {
    listen 127.0.0.1:80 default_server;

    server_name <tdom.ml>;

    location / {
        proxy_pass <tdom.ml>;
    }

}

server {
    listen 127.0.0.1:80;

    server_name <10.10.10.10>;

    return 301 https://<tdom.ml>$request_uri;
}

server {
    listen 0.0.0.0:80;
    listen [::]:80;

    server_name _;

    return 301 https://$host$request_uri;
}