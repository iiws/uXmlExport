# XmlExport

XmlExport - универсальная выгрузка данных из баз данных Firebird. Выгрузка осуществляется по набору данных, сформированному SQL-запросом и XML-шаблону. Работа с базой данных Firebird реализуется на основе компонентов FireDac. Для подключения к базе данных используется TFDConnection, для работы с запросами - TFDQuery. Для работы с XML используется [NativeXML](https://github.com/kattunga/NativeXml).

### Принцип работы выгрузки.
По SQL-запросу формируется набор данных. Для каждой записи запускается парсинг XML-шаблона, в процессе которого все значения атрибутов и нодов, соответствующие наименованиям полей запроса, заменяются на значения полей из текущего набора.

### Создание объекта.
В качестве FDConnection передается активное подключение к базе данных, с которым, в последствие, работает выгрузка.
```delphi
...
XmlExport := TXmlExport.Create(FDConnection);
...
```
### Установка XML-шаблона.
В качестве обработчика XML выступает [NativeXML](https://github.com/kattunga/NativeXml). Вся работа с шаблном реализована внутри класса TXmlExport и объекту требуется только передать содержимое шаблона.
```delphi
...
XmlExport.Xml := '<?xml version="1.0" ?><somenodes><node>some text</node></somenodes>';
...
```
### Передача SQL-запроса.
Работа с запросами к базе данных реализована через TFDQuery и происходит внутри класса TXmlExport, требуется только передать запрос.
```delphi
...
XmlExport.Sql := 'select ID, NAME from CUSTOMERS';
...
```
### Каталог выгрузки.
Каталог, в который будут сохраняться файлы выгрузки. Если не указан, то в каталоге запуска программы, будет создан каталог _exportfiles_.
```delphi
...
XmlExport.Directory := 'C:\';
...
```
### Запуск выгрузки.
Класс TXmlExport унаследован от TThread и является Suspended, поэтому, после определения всех параметров, следует запустить поток.
```delphi
...
XmlExport.Run
...
```
### Отображение процесса выгрузки.
Для отображения прогресса выгрузки предусмотрены следующие обработчики:
1. **OnProgressValue(AValue: integer)** - передается RecNo текущей записи, по которой выполняется парсинг.
2. **OnProgressMax(AMax: integer)** - передается максимальное кол-во записей из набора данных.
3. **OnProgressText(AMsg: string)** - передаются информационные сообщения, возникающие в процессе выгрузки.

### Пример.

Имеется таблица CUSTOMERS:

ID  | NAME
----|----------------------
1   | Иванов
2   | Петров

SQL-запрос:
```sql
select ID, NAME from CUSTOMERS
```

XML-шаблон, для такого запроса, будет следующего вида:
```xml
<?xml version="1.0" ?>
<customers id="ID">
  <name>NAME</name>
</customers>
```

Результатом выгрузки, в данном случае, будет 2 файла:

**1.xml**
```xml
<?xml version="1.0" ?>
<customers id="1">
  <name>Иванов</name>
</customers>
```
**2.xml**
```xml
<?xml version="1.0" ?>
<customers id="2">
  <name>Петров</name>
</customers>
```
