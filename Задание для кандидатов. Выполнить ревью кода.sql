create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)                                           -- Для объявления переменных declare используется один раз.     --Алиас обязателен для объекта
	declare @ErrorMessage varchar(max)                                                                               -- Рекомендуется при объявлении типов не использовать длину поля max

-- Проверка на корректность загрузки
	if not exists (
	select 1                                                                                                        --  Если выражение или запрос в отдельных скобках не умещаются на одной строке,  содержимое скобок начинается с новой строки, с одним отступом
	from syn.ImportFile as f                                                                                         -- При наименовании алиаса использовать первые заглавные буквы каждого слова в названии объекта, которому дают алиас
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)                                                                                                                -- Пустые строки между логическими блоками
		begin                                                                                                        -- На одном уровне с `if` и `begin/end`
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			return                                                                                                   -- Пустая строка перед return
		end

	CREATE TABLE #ProcessedRows (                                                                                    -- Таблицы именуются  по правилу {схема} . {Название}[_Постфикс] или {Название} может быть составлено из [Код источника_] + {Тип данных}
		ActionType varchar(255),
		ID int
	)
	
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal                                                                                           -- Таблицы именуются  по правилу {схема} . {Название}[_Постфикс] или {Название} может быть составлено из [Код источника_] + {Тип данных}
	from syn.SA_CustomerSeasonal cs                                                                                  -- Алиас обязателен для объекта и задается с помощью ключевого слова as
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		join syn.CustomerSystemType as cst on cs.CustomerSystemType = cst.Name                                       -- При соединение двух таблиц, сперва после on указываем поле присоединяемой таблицы
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		cs.*
		,case
			when cc.ID is null then 'UID клиента отсутствует в справочнике "Клиент"'                                 -- Результат на 1 отступ от when
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason                                                                                                -- Таблицы именуются  по правилу {схема} . {Название}[_Постфикс] или {Название} может быть составлено из [Код источника_] + {Тип данных}
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
	left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer                                                   -- Все виды join пишутся с 1 отступом
		and cc.ID_mapping_DataSource = 1
	left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1       -- Если есть and , то выравнивать его на 1 табуляцию от join         --Все виды join пишутся с 1 отступом
	left join dbo.Season as s on s.Name = cs.Season                                                                  -- Все виды join пишутся с 1 отступом
	left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType                                      -- Все виды join пишутся с 1 отступом
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null

end
