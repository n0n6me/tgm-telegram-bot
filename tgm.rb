#!/usr/local/bin/ruby

# encoding: utf-8
require 'telegram/bot'
require "pg"
require 'time'
# 
$token = ''
$pg = PG.connect :dbname => 'tgm', :user => '', :password => ''
$emoji_camera = "\u{1F3A5}"
$restrict_message = "У вас нетдостаточно прав, попробуйте уточнить свои права в службе поддержки."
$first_message = 'Для получения последних данных по продажам нажмите *Выручка по магазинам* или *Общая выручка*'
$start_menu = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [["/start"]], one_time_keyboard: false, resize_keyboard: true)
$main_menu  = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [["Больше статистики", "Общая выручка"],["Камеры","Выручка по магазинам"]], one_time_keyboard: false, resize_keyboard: true )
$tgm = Telegram::Bot::Client.new($token).api
$super_codes = ["792","1525","1752","1607","24","23","1561","1693"]
$users_table = 'users'
$chat_id_table = 'chat_id_name'
$data_table = 'retail_stat'
def get_data(chat_id,report,*shop)
	if report == 'shops'
		if check_perms(chat_id).to_i == 1
			query = "SELECT * FROM #{$data_table}"
		else
    		query = "SELECT * FROM #{$data_table} AS t1 INNER JOIN #{$users_table} AS t2 ON t1.depart_code = t2.depart_code INNER JOIN chat_id_name AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{chat_id}"
    	end
    	rs = $pg.exec(query)
    	if rs.num_tuples.zero?
    		p 'im sleeping'
    		sleep(5)
    		rs = $pg.exec(query)
    	end
    	rs.each do |row|
    		message = str_format(row["shop"],row["gross"])
    		send_message(chat_id,[message])
    	end
    	totals(chat_id)
    end
    if report == 'extend'
    	#p shop[0]
    	shop_name = $pg.exec("SELECT shop from #{$data_table}  where shop like '#{shop[0]}%'")[0]['shop']
    	cross = $pg.exec("select (sum(goods)::float/sum(cheks)) AS cross from #{$data_table} where shop like '#{shop[0]}%'")[0]["cross"].to_f.round(2).to_s
		mid_check = $pg.exec("select (sum(gross)::float/sum(cheks)) AS mid_check from #{$data_table} where shop like '#{shop[0]}%'")[0]["mid_check"] 
    	gross = $pg.exec("SELECT gross from #{$data_table}  where shop like '#{shop[0]}%'")[0]['gross']
    	#p gross
    	#p cross
    	#p mid_check
    	message = "#{shop_name}:\nСредний чек: * " + number_format(mid_check.to_i) + "*\nКроссовость: *#{cross}*\nВыручка: *" + number_format(gross) + "*"
    	#p message
    	send_message(chat_id,[message])
    end
    if report == 'sum'
    	totals(chat_id)
    end

end

def db_new_user(phone_number,chat_id)
	query = "SELECT * FROM #{$users_table} WHERE phone = '#{phone_number}'"
	rs = $pg.exec(query)
	if rs.num_tuples.zero?
		p "im sorry user with  #{phone_number} not exist"
		$tgm.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: "Сожалею, но я не могу вас идентифицировать по номеру телефона.\nОбратитесь в службу поддержки, сообщив им этот номер *#{chat_id}*." )
	else
		p rs[0]['name'] + ' ' + rs[0]['phone'].to_s
		e = $pg.exec("INSERT INTO #{$chat_id_table} VALUES ('#{chat_id}',(SELECT login FROM #{$users_table} WHERE phone = '#{phone_number}'))")
		if e
			$tgm.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: "Здравствуйте, *#{rs[0]['name']}*! Вы прошли идентификацию.\n" )
			$tgm.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: $first_message, reply_markup: $main_menu)
		else
			p "запрос на обновление бд завершился ошибкой"
		end
	end
end

def totals(chat_id)
	# подвал, добавлят сцммц гросс и дату обновления данных
    if check_perms(chat_id).to_i == 1
		sum = number_format($pg.exec("SELECT SUM(gross) FROM #{$data_table}")[0]["sum"])
    else
    	sum = number_format($pg.exec("SELECT SUM(gross) FROM #{$data_table} AS t1 INNER JOIN #{$users_table} AS t2 ON t1.depart_code = t2.depart_code INNER JOIN #{$chat_id_table} AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{chat_id}")[0]["sum"])
    end
    last_update = Time.parse($pg.exec("SELECT data from #{$data_table} limit 1")[0]["data"]).strftime("%Y-%m-%d %H:%M")
    base_message = ["Общая выручка:  *" + sum.to_s + "*", "_Данные за:  " + last_update.to_s + "_"]
    send_message(chat_id,base_message)
end

def send_message(chat_id,messages)
	messages.each do | message |
   		$tgm.send_message(chat_id: chat_id, parse_mode: 'Markdown', text: message )
    end
end

def str_format(shop,gross)
	# примерное ограничение строки на тел - 37 символов, процедура обрезает строку - магазин - цифрв до этого размера
	req_len = 37
	gross = number_format(gross)
	str = (shop + " " + gross.to_s).size
	if str > req_len
		data = shop[0,shop.size - (str - req_len)] + " *" + gross + "*"
	else
		data = shop + " " + " *" + gross + "*"
	end
	return data
end

def number_format(gross)
	# форматирует цифры 1 000, 10 000, 100 000 и тп
	if gross.to_s.size == 7
		gross = (gross.to_i / 1000000).to_s + " " +  gross.to_s[1,3].to_s + " " + gross.to_s[4,gross.to_s.size].to_s
	elsif gross.to_s.size == 8
		gross = (gross.to_i / 1000000).to_s + " " +  gross.to_s[2,3].to_s + " " + gross.to_s[5,gross.to_s.size].to_s
	elsif gross.to_s.size == 9
		gross = (gross.to_i / 1000000).to_s + " " +  gross.to_s[3,3].to_s + " " + gross.to_s[6,gross.to_s.size].to_s
	else
		gross = (gross.to_i / 1000).to_s + " " +  gross.to_s[-3,gross.size].to_s
	end
	return gross
end

def check_perms(chat_id)
	# проверка пермишенов, 0 - запрещено, 1 можно смотреть все, другие цифрмы будыт привязанны к кустам 
	query = "SELECT depart_code FROM #{$users_table} AS t1 INNER JOIN #{$chat_id_table} AS t2 ON t1.login = t2.login WHERE t2.chat_id=#{chat_id}"
	rs = $pg.exec(query)
	if rs.num_tuples.zero?
		return 0
	else
		if $super_codes.include?(rs[0]["depart_code"])
			return 1
		else
			return rs[0]["depart_code"]
		end
	end
end

# основное тело 
loop do
	begin
		Telegram::Bot::Client.run($token) do |bot|
			bot.listen do |rqst|
				Thread.start(rqst) do |rqst|
					begin
						#p rqst
						#p rqst.contact
						#if !rqst.text.nil?
						#	p Time.now.to_s + "  " + rqst.chat.id.to_s + " " + rqst.text
						#end
				    	case rqst
					    	when Telegram::Bot::Types::Message
					    		if !rqst.text.nil?
					    			name = $pg.exec("SELECT name FROM users AS t1 INNER JOIN chat_id_name AS t2 ON t1.login = t2.login WHERE t2.chat_id='#{rqst.chat.id}'")
					    			if !name.num_tuples.zero?
										p Time.now.to_s + ": #{name[0]['name']} " + rqst.chat.id.to_s + " " + rqst.text
									else 
										p Time.now.to_s + ": " + rqst.chat.id.to_s + " " + rqst.text
									end
								end
								case rqst.text
									# обновление кнопок
									when 'Выручка по магазинам'
										if check_perms(rqst.chat.id).to_i == 0 
											bot.api.send_message(chat_id: rqst.chat.id, text: $restrict_message, reply_markup: $start_menu)
										else
											get_data(rqst.chat.id,'shops')
							    	   	end
							    	when 'Общая выручка'
										if check_perms(rqst.chat.id).to_i == 0 
											bot.api.send_message(chat_id: rqst.chat.id, text: $restrict_message, reply_markup: $start_menu)
										else
											get_data(rqst.chat.id,'sum')
										end
									when 'Больше статистики'
										if check_perms(rqst.chat.id).to_i == 1
											query = "SELECT shop FROM #{$data_table}"
											cross = $pg.exec("select (sum(goods)::float/sum(cheks)) AS cross from #{$data_table}")[0]["cross"].to_f.round(2).to_s
											mid_check = $pg.exec("select (sum(gross)::float/sum(cheks)) AS mid_check from #{$data_table}")[0]["mid_check"]
											depart = "всей сети"
										else
											query = "SELECT shop FROM #{$data_table} AS t1 INNER JOIN #{$users_table} AS t2 ON t1.depart_code = t2.depart_code INNER JOIN #{$chat_id_table} AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{rqst.chat.id}"
											cross = $pg.exec("select (sum(goods)::float/sum(cheks)) AS cross from #{$data_table} as t1 inner join users_dev as t2 on t1.depart_code = t2.depart_code INNER JOIN #{$chat_id_table} AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{rqst.chat.id}")[0]["cross"].to_f.round(2).to_s
											mid_check = $pg.exec("select (sum(gross)::float/sum(cheks)) AS mid_check from #{$data_table} as t1 inner join users_dev as t2 on t1.depart_code = t2.depart_code INNER JOIN #{$chat_id_table} AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{rqst.chat.id}")[0]["mid_check"]
											depart = $pg.exec("SELECT depart_name FROM #{$users_table} AS t1 INNER JOIN #{$chat_id_table} AS t2 ON t1.login = t2.login WHERE t2.chat_id = #{rqst.chat.id}")[0]["depart_name"]
										end
										rs = $pg.exec(query)
										inline_kb = []
										rs.each do | row |
											inline_kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{row['shop']}", callback_data: row['shop'][0,3] ))
										end
										markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: inline_kb)
										bot.api.send_message(chat_id: rqst.chat.id, text: 'Выбирите магазин', reply_markup: markup)
										# сумарны срд чек и кроссовость

										cross_mid_ckeck_message = "Статистика по *#{depart}\n*Средний чек: *" + number_format(mid_check.to_i) + "*\nКроссовость: *" + cross + "*" 
										bot.api.send_message(chat_id: rqst.chat.id, parse_mode: 'Markdown', text: '_Кликните по любому магазину выше, чтобы получить по нему подробную информацию_')
										bot.api.send_message(chat_id: rqst.chat.id, parse_mode: 'Markdown', text: cross_mid_ckeck_message )

									when 'Камеры'
										if check_perms(rqst.chat.id).to_i == 1
											query = "SELECT shop FROM #{$data_table}"
										else
											query = "SELECT shop FROM #{$data_table} AS t1 INNER JOIN #{$users_table} AS t2 ON t1.depart_code = t2.depart_code INNER JOIN #{$chat_id_table} AS t3 ON t2.login = t3.login WHERE t3.chat_id = #{rqst.chat.id}"
										end
										rs = $pg.exec(query)
										inline_kb = []
										rs.each do | row |
											cam = $pg.exec("SELECT url FROM cam WHERE shop = '#{row['shop'][0,3]}'")[0]['url']
											#p cam
											inline_kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{$emoji_camera} #{row['shop']}", url: "#{cam}" ))
										end
										markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: inline_kb)
										bot.api.send_message(chat_id: rqst.chat.id, text: 'Выбирите магазин', reply_markup: markup)
										vlc_messages = ["_Для работы этого модуля необходимо установить_ *VLC* _плеер_",
											"[IOS](https://itunes.apple.com/app/apple-store/id650377962?pt=454758&ct=vodownloadpage&mt=8)",
											"[Android](https://play.google.com/store/apps/details?id=org.videolan.vlc)" ]
										vlc_messages.each do | m |
											bot.api.send_message(chat_id: rqst.chat.id, parse_mode: 'Markdown', text: m )
										end
									when '/start'
										if check_perms(rqst.chat.id).to_i == 0 
											kb = Telegram::Bot::Types::KeyboardButton.new(text: 'Отправить номер', request_contact: true)
											markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb)
											bot.api.send_message(chat_id: rqst.chat.id, text: 'Для работы с ботом вам нужно пройти идентификацию посредством отправки вашего номера телефона.', reply_markup: markup)
										else				
											bot.api.send_message(chat_id: rqst.chat.id, parse_mode: 'Markdown', text: $first_message, reply_markup: $main_menu)
										end
									when '/stop'
										kb = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
										bot.api.send_message(chat_id: rqst.chat.id, text: 'Пока', reply_markup: kb)
								end
								if rqst.contact
									# Проверка контакта
									if rqst.from.id == rqst.contact.user_id
					    				p "legal user, go to check db"
					    				db_new_user(rqst.contact.phone_number,rqst.contact.user_id)
					    			end
					    		end

							# колбеки
					    	when Telegram::Bot::Types::CallbackQuery
					    		#p rqst
					    		name = $pg.exec("SELECT name FROM users AS t1 INNER JOIN chat_id_name AS t2 ON t1.login = t2.login WHERE t2.chat_id='#{rqst.from.id}'")[0]["name"]
					    		p  Time.now.to_s + ": #{name} " + rqst.from.id.to_s + " CallbackQuery: " + rqst.data
					    		get_data(rqst.from.id,'extend',rqst.data)
					    end
					rescue Exception => e 
						p Time.now.to_s + " чтото пошло не так в основонм блоке бота"
						p e.message
						p e.backtrace.inspect
					end
				end
			end
		end
	rescue Exception => e 
		p Time.now.to_s + " блок loop"
		p e.message
		p e.backtrace.inspect
		#exist
	end
end




