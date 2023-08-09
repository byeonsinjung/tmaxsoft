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

한 번에 메시지를 가볍게 수정할 수 있도록 변환을 사용하여 커넥터를 구성할 수 있습니다. 데이터 마사지 및 이벤트 라우팅에 편리할 수 있습니다.

종류

* InsertField - 정적 데이터 또는 레코드 메타데이터를 사용하여 필드 추가
* ReplaceField - 필드 필터링 또는 이름 바꾸기
* MaskField - 유형(0, 빈 문자열 등) 또는 사용자 지정 대체(비어 있지 않은 문자열 또는 숫자 값만 해당)에 대한 유효한 null 값으로 필드를 바꿉니다.
* ValueToKey - 레코드 키를 레코드 값의 필드 하위 집합에서 형성된 새 키로 바꿉니다.
* HoistField - 전체 이벤트를 Struct 또는 Map 내부의 단일 필드로 래핑합니다.
* ExtractField - Struct 및 Map에서 특정 필드를 추출하고 이 필드만 결과에 포함
* SetSchemaMetadata - 스키마 이름 또는 버전 수정
* TimestampRouter - 원본 주제 및 타임스탬프를 기반으로 레코드의 주제를 수정합니다. 타임스탬프를 기반으로 다른 테이블이나 인덱스에 써야 하는 싱크를 사용할 때 유용합니다.
* RegexRouter - 원래 주제, 대체 문자열 및 정규식을 기반으로 레코드의 주제를 수정합니다.
* Filter - 모든 추가 처리에서 메시지를 제거합니다. 특정 메시지를 선택적으로 필터링하기 위해 술어 와 함께 사용됩니다 .
* InsertHeader - 정적 데이터를 사용하여 헤더 추가
* HeadersFrom - 키 또는 값의 필드를 레코드 헤더로 복사 또는 이동합니다.
* DropHeaders - 이름으로 헤더 제거

이 중 InsertField를 이용해서 'from'이라는 컬럼에 'maria'라는 값을 추가하는 테스트

### Maria Source Connector 등록 - InsertField 적용

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
        "table.whitelist": "test",
        "transforms": "InsertSource",
        "transforms.InsertSource.type": "org.apache.kafka.connect.transforms.InsertField$Value",
        "transforms.InsertSource.static.field": "from",
        "transforms.InsertSource.static.value": "maria"
    }
}
```

- transforms: 변환이 적용될 순서를 지정하는 변환의 별칭 목록입니다.
- transforms.$alias.type: 변환에 대한 정규화된 클래스 이름입니다.
- static.field: 정적 데이터 필드의 필드 이름입니다.
- static.value: 필드 이름이 구성된 경우 정적 필드 값입니다.

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

(1절과 동일)

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

{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"},{"type":"string","optional":true,"field":"from"}],"optional":false,"name":"test"},"payload":{"id":101,"name":"kih","role":"admin","from":"maria"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"},{"type":"string","optional":true,"field":"from"}],"optional":false,"name":"test"},"payload":{"id":102,"name":"lwj","role":"user","from":"maria"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"},{"type":"string","optional":true,"field":"from"}],"optional":false,"name":"test"},"payload":{"id":103,"name":"aht","role":"user","from":"maria"}}
{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"id"},{"type":"string","optional":true,"field":"name"},{"type":"string","optional":true,"field":"role"},{"type":"string","optional":true,"field":"from"}],"optional":false,"name":"test"},"payload":{"id":104,"name":"bss","role":"user","from":"maria"}}
...
```

<br>

### Postgre 데이터 확인

```sql
> SELECT * FROM test;

+-----+------+-------+-------+
| id  | name | role  | from  |
+-----+------+-------+-------+
| 101 | kih  | admin | maria |
| 102 | lwj  | user  | maria |
| 103 | aht  | user  | maria |
| 104 | bss  | user  | maria |
+-----+------+-------+-------+
```

* from이라는 컬럼에 maria라는 값이 추가된 것을 확인
