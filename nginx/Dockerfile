FROM nginx:mainline-alpine

RUN mkdir -p /etc/nginx/templates
COPY templates/* /etc/nginx/templates/
COPY nginx.conf /etc/nginx/

CMD ["nginx"]
EXPOSE 80
