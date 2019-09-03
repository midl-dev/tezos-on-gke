FROM python:alpine
WORKDIR /build
COPY . /build
RUN pip install -r requirements.txt
ENTRYPOINT ["gunicorn", "-b", ":31764", "wsgi" ]
