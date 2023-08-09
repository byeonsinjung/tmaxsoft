## 1. Maria -> Postgre CDC

### JDBC Connector 및 Maria JDBC 드라이버 다운로드

(다운로드 과정 생략)

```shell
$ ls -l ${KAFKA_HOME}/plugins/

...
confluentinc-kafka-connect-jdbc-10.7.3/
...
```

```shell
$ ls -l ${KAFKA_HOME}/plugins/confluentinc-kafka-connect-jdbc-10.7.3/lib/

...
mariadb-java-client-2.4.0.jar
...
postgresql-42.4.3.jar
...
```

<br>

### Connect 설정

```shell
$ vi ${KAFKA_HOME}/config/connect-distributed.properties

bootstrap.servers=192.168.53.21:9092,192.168.53.22:9092,192.168.53.23:9092
group.id=connect-cluster
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=1
config.storage.topic=connect-configs
config.storage.replication.factor=1
status.storage.topic=connect-status
status.storage.replication.factor=1
offset.flush.interval.ms=10000
plugin.path=/home/kafka/kafka_2.13-3.4.0/plugins
```

<br>

### Connect 기동

```shell
$ ${KAFKA_HOME}/bin/connect-distributed.sh -daemon ${KAFKA_HOME}/config/connect-distributed.properties
```

<br>

### Connect 접속

```shell
GET http://192.168.53.24:8083
```

#### 응답

```json
{
    "version": "3.4.0",
    "commit": "2e1947d240607d53",
    "kafka_cluster_id": "B0lrZBh0TJWJ9Ifr-Me8AQ"
}
```

<br>

### 등록된 Connector 확인

```shell
GET http://192.168.53.24:8083/connectors
```

#### 응답

```json
[]
```

* 현재 아무것도 없음

<br>

### Maria Source Connector 등록

```shell
POST http://192.168.53.24:8083/connectors
```

```json
{
    "name": "maria-source",
    "config": {
        "connector.class": "JdbcSource",
        "mode": "bulk",
        "topic.prefix": "bss-connect-",
        "topic.creation.default.partitions": "1",
        "connection.password": "inner",
        "tasks.max": "1",
        "connection.user": "inner",
        "topic.creation.default.replication.factor": "1",
        "connection.url": "jdbc:mysql://192.168.53.18:32002/hfi",
        "table.whitelist": "test"
    }
}
```

#### 응답

```json
{
    "name": "maria-source",
    "config": {
        "connector.class": "JdbcSource",
        ...
    },
    "tasks": [],
    "type": "source"
}
```

<br>

### Postgre Sink Connector 등록

```shell
POST http://192.168.53.24:8083/connectors
```

```json
{
    "name": "postgre-sink",
    "config": {
        "connector.class": "JdbcSink",
        "tasks.max": "1",
        "connection.url": "jdbc:postgresql://192.168.53.18:32000/hfi",
        "connection.user": "inner",
        "connection.password": "inner",
        "auto.create": "false",
        "auto.evolve": "false",
        "topics": "bss-connect-test",
        "table.name.format": "public.test",
        "insert.mode": "upsert",
        "pk.mode": "record_value",
        "pk.fields": "id"
    }
}
```

#### 응답

```json
{
    "name": "postgre-sink",
    "config": {
        "connector.class": "JdbcSink",
        ...
    },
    "tasks": [],
    "type": "sink"
}
```

<br>

### 등록된 Connector 확인

```shell
GET http://192.168.53.24:8083/connectors
```

#### 응답

```json
[
    "postgre-sink",
    "maria-source"
]
```

<br>

### 등록된 Connector 상태 확인

```shell
GET http://192.168.53.24:8083/connectors/maria-source/status
```

#### 응답

```json
{
    "name": "maria-source",
    "connector": {
        "state": "RUNNING",
        "worker_id": "127.0.1.1:8083"
    },
    "tasks": [
        {
            "id": 0,
            "state": "RUNNING",
            "worker_id": "127.0.1.1:8083"
        }
    ],
    "type": "source"
}
```
* RUNNING 인지 확인

(Postgre도 동일)

<br>

### Maria에 데이터 삽입

```sql
> INSERT INTO test (name, role) VALUES ('kih', 'admin');
> INSERT INTO test (name, role) VALUES ('lwj', 'user');
> INSERT INTO test (name, role) VALUES ('aht', 'user');
> INSERT INTO test (name, role) VALUES ('bss', 'user');
> SELECT * FROM test;

+-----+------+-------+
| id  | name | role  |
+-----+------+-------+
| 101 | kih  | admin |
| 102 | lwj  | user  |
| 103 | aht  | user  |
| 104 | bss  | user  |
+-----+------+-------+
```

<br>

### Kafka 메시지 확인

```shell
$ ${KAFKA_HOME}/bin/kafka-console-consumer.sh --bootstrap-server 192.168.53.21:9092,192.168.53.22:9092,192.168.53.23:9092 --topic bss-connect-test

{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":101,"name":"bss","role":"user"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":102,"name":"kih","role":"admin"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":103,"name":"lwj","role":"user"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":104,"name":"smj","role":"admin"}}
...
```

<br>

### Postgre 데이터 확인

```sql
> SELECT * FROM test;

+-----+------+-------+
| id  | name | role  |
+-----+------+-------+
| 101 | kih  | admin |
| 102 | lwj  | user  |
| 103 | aht  | user  |
| 104 | bss  | user  |
+-----+------+-------+
```

<br>

## 2. Transformation

### Maria Source Connector 등록

```shell
POST http://192.168.53.24:8083/connectors
```

```json
{
    "name": "maria-source",
    "config": {
        "connector.class": "JdbcSource",
        "mode": "bulk",
        "topic.prefix": "bss-connect-",
        "topic.creation.default.partitions": "1",
        "connection.password": "inner",
        "tasks.max": "1",
        "connection.user": "inner",
        "topic.creation.default.replication.factor": "1",
        "connection.url": "jdbc:mysql://192.168.53.18:32002/hfi",
        "table.whitelist": "test"
    }
}
```

#### 응답

```json
{
    "name": "maria-source",
    "config": {
        "connector.class": "JdbcSource",
        ...
    },
    "tasks": [],
    "type": "source"
}
```

<br>

### Postgre Sink Connector 등록

```shell
POST http://192.168.53.24:8083/connectors
```

```json
{
    "name": "postgre-sink",
    "config": {
        "connector.class": "JdbcSink",
        "tasks.max": "1",
        "connection.url": "jdbc:postgresql://192.168.53.18:32000/hfi",
        "connection.user": "inner",
        "connection.password": "inner",
        "auto.create": "false",
        "auto.evolve": "false",
        "topics": "bss-connect-test",
        "table.name.format": "public.test",
        "insert.mode": "upsert",
        "pk.mode": "record_value",
        "pk.fields": "id"
    }
}
```

#### 응답

```json
{
    "name": "postgre-sink",
    "config": {
        "connector.class": "JdbcSink",
        ...
    },
    "tasks": [],
    "type": "sink"
}
```

<br>

### 등록된 Connector 확인

```shell
GET http://192.168.53.24:8083/connectors
```

#### 응답

```json
[
    "postgre-sink",
    "maria-source"
]
```

<br>

### 등록된 Connector 상태 확인

```shell
GET http://192.168.53.24:8083/connectors/maria-source/status
```

#### 응답

```json
{
    "name": "maria-source",
    "connector": {
        "state": "RUNNING",
        "worker_id": "127.0.1.1:8083"
    },
    "tasks": [
        {
            "id": 0,
            "state": "RUNNING",
            "worker_id": "127.0.1.1:8083"
        }
    ],
    "type": "source"
}
```
* RUNNING 인지 확인

(Postgre도 동일)

<br>

### Maria에 데이터 삽입

```sql
> INSERT INTO test (name, role) VALUES ('kih', 'admin');
> INSERT INTO test (name, role) VALUES ('lwj', 'user');
> INSERT INTO test (name, role) VALUES ('aht', 'user');
> INSERT INTO test (name, role) VALUES ('bss', 'user');
> SELECT * FROM test;

+-----+------+-------+
| id  | name | role  |
+-----+------+-------+
| 101 | kih  | admin |
| 102 | lwj  | user  |
| 103 | aht  | user  |
| 104 | bss  | user  |
+-----+------+-------+
```

<br>

### Kafka 메시지 확인

```shell
$ ${KAFKA_HOME}/bin/kafka-console-consumer.sh --bootstrap-server 192.168.53.21:9092,192.168.53.22:9092,192.168.53.23:9092 --topic bss-connect-test

{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":101,"name":"bss","role":"user"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":102,"name":"kih","role":"admin"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":103,"name":"lwj","role":"user"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"}],"optional":false,"name":"test"},"payload":{"id":104,"name":"smj","role":"admin"}}
...
```

<br>

### Postgre 데이터 확인

```sql
> SELECT * FROM test;

+-----+------+-------+
| id  | name | role  |
+-----+------+-------+
| 101 | kih  | admin |
| 102 | lwj  | user  |
| 103 | aht  | user  |
| 104 | bss  | user  |
+-----+------+-------+
```
