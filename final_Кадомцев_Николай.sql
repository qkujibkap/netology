SET search_path TO bookings

--Задание 1 (готово)
--Выведите название самолетов, которые имеют менее 50 посадочных мест?
select 
a.aircraft_code as "Код борта",
a.model as "Название борта",
count(s.seat_no) as "Мест"
from aircrafts a 
left join seats s on a.aircraft_code = s.aircraft_code
group by a.aircraft_code
having count(s.seat_no) < 50

--Задание 2 (готово)
--Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
select date_trunc('month', book_date), round(100*((sum(total_amount)-
lag(sum(total_amount))over (order by date_trunc('month', book_date))
	)
	/
	lag(sum(total_amount))over (order by date_trunc('month', book_date)))
	,2) as "%"
from bookings
group by date_trunc('month', book_date)

--Задание 3 (готово)
--Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
with sm as (
select 'Business' = any(array_agg(distinct fare_conditions)) as klass,a.model as nameair from seats s 
left join aircrafts a on a.aircraft_code = s.aircraft_code 
group by a.model)
select nameair from sm
where sm.klass = false

--Задание 4 (готово)
--Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день,
--учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта
--таких самолетов вылетало более одного.
--В результате должны быть код аэропорта, дата, количество пустых мест и накопительный итог."
with
mest_v_sam as (select aircraft_code, count(aircraft_code)as mest from seats s
				group by (aircraft_code)),
zanyatie_mesta as (select flight_id,count(flight_id)  from boarding_passes bp
					group by flight_id),
vileteli as (select flight_id, departure_airport, aircraft_code  from flights f
				where status = 'Departed' or status = 'Arrived'),
www as (select * from vileteli
			left join zanyatie_mesta using (flight_id)
			join mest_v_sam using (aircraft_code)),
eee as (select www.departure_airport, www.mest,date(f.actual_departure)  from www 
	left join flights f using (flight_id)
	where count isnull
	order by date),
bol1 as (select departure_airport, count(date) > 1 is true as b1, date from eee
			group by departure_airport, date)
select departure_airport, date, mest,
coalesce (sum(mest) over (partition by departure_airport,date order by date rows between unbounded preceding and current row),0) as nakopit_itog
from eee
inner join bol1 using (departure_airport, date) where b1 is true
order by departure_airport, date

--Задание 5 (готово)
--Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.
with ap as (
select concat(dep.airport_name ,'-',arr.airport_name) as routes,count(flight_id) as perel
from flights f 
inner join airports dep on f.departure_airport = dep.airport_code --подключил назввания для аэропортов вылета
inner join airports arr on f.arrival_airport  = arr.airport_code --подключил назввания для аэропортов прилета
group by (routes))
select routes as "Маршрут",perel*100/sum(perel) over() as proc from ap

--Задание 6 (готово)
--Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код
--оператора - это три символа после +7
with ph as(select contact_data ->> 'phone' as phone from tickets t )
select substring(phone,position('+7'in phone)+2,3) as code, count(*) from ph
group by (code)
order by (code)

--Задание 7 (готово)
--Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе.
with ddd as (
select concat(f.departure_airport,'-',f.arrival_airport) as routes,
case
	when round(sum(st.Stoimots)/1000000,2) >= 150 then 'high'
	when round(sum(st.Stoimots)/1000000,2) < 50 then 'low'
	else 'middle'
end as klas
from flights f 
join
	(select tf.flight_id, sum(amount) as Stoimots from ticket_flights tf --стоимость перелета
	group by tf.flight_id ) as st on st.flight_id = f.flight_id 
group by routes)
select count(routes),klas from ddd
group by klas

--Задание 8 (готово)
--Вычислите медиану стоимости билетов, медиану размера бронирования и отношение медианы
--бронирования к медиане стоимости билетов, округленной до сотых.
with bil as(select Percentile_cont (0.5) WITHIN GROUP (ORDER BY amount) as median_bil
  from ticket_flights tf),
bron as(select Percentile_cont (0.5) WITHIN GROUP (ORDER BY total_amount) as median_bron
 from bookings b ),
otn as (select br.median_bron/bi.median_bil as otn from bil bi, bron br)
select br.median_bron, bi.median_bil,round(cast(otn.otn as numeric),2) as otnoshenie from bil bi, bron br, otn

--Задание 9 (готово)
--Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти
--расстояние между аэропортами и с учетом стоимости билетов получить искомый результат.
--Для поиска расстояния между двумя точка на поверхности Земли нужно использовать
--дополнительный модуль earthdistance (https://postgrespro.ru/docs/postgresql/15/earthdistance). Для
--работы данного модуля нужно установить еще один модуль cube
--(https://postgrespro.ru/docs/postgresql/15/cube).
--Установка дополнительных модулей происходит через оператор create extension название_модуля.
--Функция earth_distance возвращает результат в метрах.
--В облачной базе данных модули уже установлены.
with 
	dist as (select distinct 
		departure_airport,
		arrival_airport,
		earth_distance (ll_to_earth(dep.latitude,dep.longitude), ll_to_earth(arr.latitude,arr.longitude))/1000 as distance_km
		from flights f 
		inner join airports dep on f.departure_airport = dep.airport_code 
		inner join airports arr on f.arrival_airport  = arr.airport_code)
select min(amount/distance_km) as minimalnaya_stoimost from dist
	left join (select amount, departure_airport, arrival_airport from ticket_flights tf 
				inner join flights f  using (flight_id)
				group by amount, departure_airport, arrival_airport) as ss on 
				concat(dist.departure_airport ,dist.arrival_airport) = concat(ss.departure_airport, ss.arrival_airport)
