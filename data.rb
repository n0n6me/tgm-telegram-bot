#!/usr/local/bin/ruby
require 'tiny_tds'
require "pg"
server = 'wds04'
database = 'Розница'
username = ''
password = ''
$holding = TinyTds::Client.new username: username, password: password, host: server, port: 1433, database: database
$users_table = 'users'
$data_table = 'retail_stat'

def data
	current_time = Time.now
	start_time = "40" + Time.now.strftime("%y-%m-%d") + " 00:00:00.000"
	end_time = "40" + Time.now.strftime("%y-%m-%d") + " 23:59:00.000"
	#start_time = '4018-03-22 00:00:00.000'
	#end_time = '4018-03-23 00:00:00.000'
	msql = "SELECT 
         Магазин AS shop
        ,SUM(CASE WHEN ВидОперации = 0xA4FEEDD07DA60D484EE48B6C4BE07A6A THEN Выручка ELSE - Выручка END) AS gross
        ,COUNT(CASE WHEN ВидОперации = 0xA4FEEDD07DA60D484EE48B6C4BE07A6A THEN 1 ELSE NULL END) AS checks
        ,SUM(CASE WHEN ВидОперации = 0xA4FEEDD07DA60D484EE48B6C4BE07A6A THEN Количество ELSE - Количество END) AS goods
         , t4.[Наименование] AS depart_name
		 , t4.[Код] AS depart_code
        
FROM
    (SELECT 
             _IDRRef AS ЧекСсылка
            ,_Fld3365RRef AS ВидОперации
            ,_Fld3371RRef AS МагазинСсылка
    FROM _Document169 (NOLOCK)
    WHERE _Date_Time >= '#{start_time}' and _Date_Time <= '#{end_time}') A
        inner join 
    (SELECT 
             _Document169_IDRRef AS ЧекСсылка
            ,SUM(_Fld3390) AS Количество
            ,SUM(_Fld3392) AS Выручка
    FROM _Document169_VT3386 (NOLOCK)
    GROUP BY _Document169_IDRRef) B ON A.ЧекСсылка = B.ЧекСсылка
        inner join 
    (SELECT 
             _IDRRef AS МагазинСсылка
            ,_Description AS Магазин
    FROM _Reference58 (NOLOCK)) C ON A.МагазинСсылка = C.МагазинСсылка
		left join 
		www.[wiki].[Справочник.ЦФО] as t3 on C.Магазин = t3.[Наименование]
	left join
		www.[wiki].[Справочник.ЦФО] as t4 on t3.[ВнутреннийИдентификаторРодителя] = t4.[ВнутреннийИдентификатор]
    GROUP BY Магазин,	t4.[Наименование], t4.[Код]"
	result = $holding.execute(msql)
	con = PG.connect :dbname => 'tgm', :user => 'pgsql'
	con.exec "DELETE FROM #{$data_table}"
	result.each do |row|
		p row
		if row['depart_name'] == nil
			row['depart_name'] = 'Куст 4'
		end
		if row['depart_code'] == nil
			row['depart_code'] = '1605'
		end
			
		con.exec "INSERT INTO #{$data_table} VALUES ('#{current_time}','#{row['shop']}', '#{row['gross'].to_i}','#{row['checks']}','#{row['goods'].to_i}', '#{row['depart_name']}','#{row['depart_code']}')"
	end
end


def users
	con = PG.connect :dbname => 'tgm', :user => '', :password => ''
	con.exec "DELETE FROM #{$users_table}"
 	msqls = [
 		"SELECT  
 			t2.[Сотрудник.ЦифровойЛогин] AS login
			,t3.[Наименование] AS name
			,t1.[Наименование] AS derart_name
			,t1.Код AS derart_code
			,t3.[Телефон.Мобильный] AS phone
		FROM  www.[wiki].[Справочник.ЦФО] AS t1
			INNER JOIN www.[wiki].[Справочник.ШтатноеРасписание] AS t2 ON t1.[ВнутреннийИдентификатор] = t2.[Подразделение]
			INNER JOIN www.[wiki].[Справочник.Сотрудники] AS t3 ON t2.Сотрудник = t3.[ВнутреннийИдентификатор]
		WHERE t2.[Подразделение.Наименование] LIKE 'Куст%'",
		"SELECT 
			t2.[Сотрудник.ЦифровойЛогин] AS login
			,t3.[Наименование] AS name
			,t1.[Наименование] AS derart_name
			,t1.Код as derart_code
			,t3.[Телефон.Мобильный] AS phone
		FROM  www.[wiki].[Справочник.ЦФО] AS t1
			INNER JOIN www.[wiki].[Справочник.ШтатноеРасписание] AS t2 ON t1.[ВнутреннийИдентификатор] = t2.[Подразделение]
			INNER JOIN www.[wiki].[Справочник.Сотрудники] AS t3 ON t2.Сотрудник = t3.[ВнутреннийИдентификатор]
		WHERE t2.[Подразделение.Наименование] 
			IN 
			('Розничная сеть','Розница', 'Региональная розница', 'Техническое обеспечение','Планирование и учет','Администрация','Управление ассортиментом','Стратегический маркетинг')
		AND t2.[Наименование] 
			IN 
			('Руководитель','Акционер')"]
	msqls.each do |msql|
		result = $holding.execute(msql)
		result.each do |row|
			con.exec "INSERT INTO #{$users_table} VALUES ('#{row['login']}', '#{row['name']}','#{row['derart_name']}','#{row['derart_code']}','#{row['phone'].gsub(/\D/,'')}')"
			p row
		end
	end
end

if ARGV[0] == 'data'
	data
elsif ARGV[0] == 'users'
	users
end

	


