## SSL을 사용한 암호화 및 인증

### 이유

- 카프카(kafka)는 기본적으로 보안설정이 적용되지 않음
- 어떠한 클라이언트(client)이든 카프카와 동일한 네트워크 대역에 있다면 자유롭게 접근할 수 있음
- 악의적인 사용자에 의해 손쉽게 주요 정보가 유출될 위험이 존재

### 순서

1. 각 Kafka 브로커에 대한 SSL 키 및 인증서 생성
2. 자체 CA 생성
3. 인증서 서명
4. Kafka 브로커 설정
5. Kafka 클라이언트 설정

### 1. 각 Kafka 브로커에 대한 SSL 키 및 인증서 생성

```shell
#### SSL 키 스토어 생성 ####
$ keytool -keystore broker.keystore.jks -alias localhost \
    -validity 365 -genkey -keyalg RSA -storetype pkcs12

...
What is your first and last name?
  [Unknown]:  localhost
...
Is CN=localhost, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown correct?
  [no]:  yes

#### SSL 인증서(미서명) 생성 ####
$ keytool -keystore broker.keystore.jks -alias localhost -certreq -file broker-csr
```

### 2. 자체 CA 생성

```shell
#### CA 및 CA 인증서 생성 ####
$ openssl req -new -x509 -keyout ca-key -out ca-cert

...
Common Name (eg, your name or your servers hostname) []:localhost
...

#### 트러스트 스토어 생성 및 CA 인증서 추가 ####
$ keytool -keystore client.truststore.jks -alias CARoot -import -file ca-cert

...
Trust this certificate? [no]:  yes
Certificate was added to keystore
```

### 3. 인증서 서명

```shell
#### SSL 인증서 서명 ####
$ openssl x509 -req -CA ca-cert -CAkey ca-key \
    -in broker-csr -out broker-cert -days 365 -CAcreateserial

Signature ok
...

#### SSL 키 스토어에 CA 인증서 추가 ####
$ keytool -keystore broker.keystore.jks -alias CARoot -import -file ca-cert

...
Trust this certificate? [no]:  yes
Certificate was added to keystore

#### SSL 키 스토어에 SSL 인증서 추가 ####
$ keytool -keystore broker.keystore.jks -alias localhost -import -file broker-cert

...
Certificate reply was installed in keystore
```

### 4. Kafka 브로커 설정

```shell
#### server.properties에 설정 추가 ####
listeners=PLAINTEXT://localhost:9092,SSL://localhost:9093
ssl.keystore.location=[PATH]/broker.keystore.jks
ssl.keystore.password=[PASSWORD]
ssl.key.password=[PASSWORD]

#### 재기동 ####
$ kafka-server-stop.sh
$ kafka-server-start.sh server.properties

#### SSL 접속 확인 ####
$ openssl s_client -debug -connect localhost:9093 -tls1_2

...
Server certificate
-----BEGIN CERTIFICATE-----
MIIDKjCCAhICCQD44suXKKsQ+DANBgkqhkiG9w0BAQsFADBCMQswCQYDVQQGEwJY
...
    Verify return code: 19 (self signed certificate in certificate chain)
```

### 5. Kafka 클라이언트 설정

```shell
#### client-ssl.properties 생성 ####
security.protocol=SSL
ssl.truststore.location=[PATH]/client.truststore.jks
ssl.truststore.password=[PASSWORD]

#### 프로듀서 접속 확인 ####
$ kafka-console-producer.sh --bootstrap-server localhost:9093 \
    --topic test --producer.config client-ssl.properties

>Hello World!

#### 컨슈머 접속 확인 ####
$ kafka-console-consumer.sh --bootstrap-server localhost:9093 \
    --topic test --consumer.config client-ssl.properties --from-beginning

Hello World!
```

## ZooKeeper mTLS 인증

본 절은 'SSL을 사용한 암호화 및 인증' 절을 선행했다는 전제 하에 서술한다.

### 순서

1. Zookeeper에 대한 SSL 키 및 인증서 생성
2. 트러스트 스토어 생성
3. 인증서 서명
4. Zookeeper 설정
5. Kafka 브로커 설정

### 1. Zookeeper에 대한 SSL 키 및 인증서 생성

```shell
#### SSL 키 스토어 생성 ####
$ keytool -keystore zookeeper.keystore.jks -alias localhost \
    -validity 365 -genkey -keyalg RSA -storetype pkcs12

...
What is your first and last name?
  [Unknown]:  localhost
...
Is CN=localhost, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown correct?
  [no]:  yes

#### SSL 인증서(미서명) 생성 ####
$ keytool -keystore zookeeper.keystore.jks -alias localhost -certreq -file zookeeper-csr
```

### 2. 트러스트 스토어 생성

```shell
#### 브로커 트러스트 스토어 생성 및 CA 인증서 추가 ####
$ keytool -keystore broker.truststore.jks -alias CARoot -import -file ca-cert

...
Trust this certificate? [no]:  yes
Certificate was added to keystore

#### Zookeeper 트러스트 스토어 생성 및 CA 인증서 추가 ####
$ keytool -keystore zookeeper.truststore.jks -alias CARoot -import -file ca-cert

...
Trust this certificate? [no]:  yes
Certificate was added to keystore
```

### 3. 인증서 서명

```shell
#### SSL 인증서 서명 ####
$ openssl x509 -req -CA ca-cert -CAkey ca-key \
    -in zookeeper-csr -out zookeeper-cert -days 365 -CAcreateserial

Signature ok
...

#### SSL 키 스토어에 CA 인증서 추가 ####
$ keytool -keystore zookeeper.keystore.jks -alias CARoot -import -file ca-cert

...
Trust this certificate? [no]:  yes
Certificate was added to keystore

#### SSL 키 스토어에 SSL 인증서 추가 ####
$ keytool -keystore zookeeper.keystore.jks -alias localhost -import -file zookeeper-cert

...
Certificate reply was installed in keystore
```

### 4. Zookeeper 설정

```shell
#### zookeeper.properties에 설정 추가 ####
secureClientPort=2182
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory
authProvider.x509=org.apache.zookeeper.server.auth.X509AuthenticationProvider
ssl.keyStore.location=[PATH]/zookeeper.keystore.jks
ssl.keyStore.password=[PASSWORD]
ssl.trustStore.location=[PATH]/zookeeper.truststore.jks
ssl.trustStore.password=[PASSWORD]

#### Kafka 중지 및 Zookeeper 재기동 ####
$ kafka-server-stop.sh
$ zookeeper-server-stop.sh
$ zookeeper-server-start.sh zookeeper.properties

#### SSL 접속 확인 ####
$ openssl s_client -debug -connect localhost:2182 -tls1_2

...
Server certificate
-----BEGIN CERTIFICATE-----
MIIDKjCCAhICCQD44suXKKsQ+DANBgkqhkiG9w0BAQsFADBCMQswCQYDVQQGEwJY
...
    Verify return code: 19 (self signed certificate in certificate chain)
```

### 5. Kafka 브로커 설정

```shell
#### server.properties에 설정 추가 ####
#zookeeper.connect=localhost:2181
zookeeper.connect=localhost:2182
zookeeper.ssl.client.enable=true
zookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
zookeeper.ssl.keystore.location=[PATH]/broker.keystore.jks
zookeeper.ssl.keystore.password=[PASSWORD]
zookeeper.ssl.truststore.location=[PATH]/broker.truststore.jks
zookeeper.ssl.truststore.password=[PASSWORD]
zookeeper.set.acl=true

#### Kafka 기동 ####
$ kafka-server-start.sh server.properties

#### SSL 접속 확인 ####
$ openssl s_client -debug -connect localhost:9093 -tls1_2

...
Server certificate
-----BEGIN CERTIFICATE-----
MIIDKjCCAhICCQD44suXKKsQ+DANBgkqhkiG9w0BAQsFADBCMQswCQYDVQQGEwJY
...
    Verify return code: 19 (self signed certificate in certificate chain)
```
