--- Tabla Dimension del cliente
create table dim_cliente (
    cliente_key int identity(1,1) constraint  pk_cliente primary key,
    customerid nvarchar(5),
    nombre_cliente nvarchar(100),
	sexo varchar(15),
	fecha_nacimiento date,
    pais nvarchar(50),
    ciudad nvarchar(50),
    codigo_postal nvarchar(10),
    telefono nvarchar(20),
	categoria nvarchar(20),
	asesor  nvarchar(80)
);

--- Tabla dimesion del producto
--drop table dim_producto

alter table dim_producto drop column proveedorid
alter table dim_producto add proveedor_key int
alter table dim_producto add constraint fk_producto_proveedor 
foreign key(proveedor_key)
references dim_proveedor(proveedor_key) 

create table dim_producto (
    producto_key int identity(1,1) constraint  pk_prodcuto primary key,
    productid int,
    nombre_producto nvarchar(100),
    categoria nvarchar(20),
	proveedor_key int,
    cantidad_por_unidad nvarchar(50),
    precio_unitario decimal(10,2),
    unidades_en_stock int,
    unidades_en_orden int);

---Tabla dimension del empleado
--drop table dim_empleado

create table dim_empleado (
    empleado_key int identity(1,1) constraint  pk_empleado primary key,
    employeeid int,
    nombre_empleado nvarchar(100),
    titulo nvarchar(50),
    fecha_contratación date,
    pais nvarchar(50),
    ciudad nvarchar(50)
);

--- Tabla dimesion del proveedor
--drop table dim_proveedor

create table dim_proveedor (
    proveedor_key int identity(1,1) constraint  pk_proveedor primary key,
    supplierid int,
    nombre_proveedor nvarchar(100),
    país nvarchar(50),
    ciudad nvarchar(50),
    telefono nvarchar(20),
    fax nvarchar(20)
);

--- Tabla dimension del tiempo
--drop table dim_tiempo

create table dim_tiempo (
    fecha_key int constraint  pk_tiempo primary key identity,
    fecha_completa date,
    annio int,
    mes int,
    dia int,
    cuatrimestre int,
    trimestre int,
    semana int,
    dia_semana nvarchar(10),
	dia_annio int
);


---Dimesion de transportista
create table dim_transportista (
    transportista_key int identity(1,1) constraint  pk_transportista primary key,
    shipperid int,
    nombre_transportista nvarchar(100),
    telefono nvarchar(20)
);


--- Rellenar la tabla de tiempo
declare @fecha_inicial date = '2020-01-01';  -- fecha inicial
declare @fecha_final date = '2025-12-31';    -- fecha final

while @fecha_inicial <= @fecha_final
begin
    insert into dim_tiempo 
	(fecha_completa, annio, mes, dia, cuatrimestre, 
	trimestre, semana, dia_semana,dia_annio)
    values (
        @fecha_inicial,                               -- fecha_completa
        year(@fecha_inicial),                         -- año
        month(@fecha_inicial),                        -- mes
        day(@fecha_inicial),                          -- día
        case                                         -- cuatrimestre
            when month(@fecha_inicial) between 1 and 3 then 1
            when month(@fecha_inicial) between 4 and 6 then 2
            when month(@fecha_inicial) between 7 and 9 then 3
            else 4
        end,
        case                                         -- trimestre
            when month(@fecha_inicial) between 1 and 3 then 1
            when month(@fecha_inicial) between 4 and 6 then 2
            when month(@fecha_inicial) between 7 and 9 then 3
            else 4
        end,
        datepart(week, @fecha_inicial),               -- semana (número de la semana)
        datename(weekday, @fecha_inicial) ,            -- día_semana (nombre del día de la semana)
        datepart(dayofyear,@fecha_inicial)
	);

    -- incrementar la fecha actual en un día
    set @fecha_inicial = dateadd(day, 1, @fecha_inicial);
end;


--- Tabla de hecho de las ventas
create table fact_ventas (
    venta_id int identity(1,1) primary key,
    fecha_key int,
    cliente_key int,
    producto_key int,
    empleado_key int,
    proveedor_key int,
	transportista_key int,
    cantidad int,
    precio_unitario decimal(10,2),
    descuento decimal(5,2),
    total_venta decimal(12,2),
    )

--- Vincualar las tablas de dimesion a las de los hechos


alter table fact_ventas add constraint    fk_ventas_tiempo	foreign key (fecha_key) references dim_tiempo(fecha_key);
alter table fact_ventas add constraint   fk_ventas_cliente    foreign key (cliente_key) references dim_cliente(cliente_key);
alter table fact_ventas add constraint  fk_ventas_producto    foreign key (producto_key) references dim_producto(producto_key);
alter table fact_ventas add constraint  fk_ventas_empleado    foreign key (empleado_key) references dim_empleado(empleado_key);
alter table fact_ventas add constraint fk_ventas_proveedor    foreign key (proveedor_key) references dim_proveedor(proveedor_key);
alter table fact_ventas add constraint fk_ventas_transportista    foreign key (transportista_key) references dim_transportista(transportista_key);


----------------------------

ALTER view [dbo].[vfact_ventas] as
select 
    (select fecha_key from dim_tiempo where fecha = cast(o.orderdate as date))fecha_key,
    (select cliente_key from dim_cliente where customer_id = o.customerid) cliente_key,
    (select producto_key from dim_producto where isnumeric(product_id)=1 
	and cast(product_id as varchar(10)) = cast(od.productid as varchar(10)))producto_key,


    (select empleado_key from dim_empleado where substring(employee_id,2,3) = o.employeeid
	and substring(employee_id,1,1)=1) empleado_key,

    (select transportista_key from dim_transportista where transportista_key = o.shipvia) transportista_key,
	od.quantity,
    od.unitprice,
    od.discount,
    od.quantity * od.unitprice * (1 - od.discount) sales
from staging.dbo.orders o
inner join staging.dbo.[order_details] od on o.orderid = od.orderid
inner join staging.dbo.products p on od.productid = p.productid

union all 

select 
(select fecha_key from dim_tiempo where fecha = p.fecha_pedido)fecha_key,
    (select cliente_key from dim_cliente where customer_id = p.codigo_cliente and fuente='JARDINERIA')cliente_key,
   
    (select producto_key from dim_producto where isnumeric(product_id)=0 and 
	product_id = dp.codigo_producto)producto_key,	
  
   (select empleado_key from dim_empleado 
	where substring(employee_id,2,3) = cl.codigo_empleado_rep_ventas
	and substring(employee_id,1,1)=2)empleado_key,
    1 transportista_key,
	dp.cantidad,
    dp.precio_unidad,
    0 discount,
    dp.cantidad * dp.precio_unidad  sales
from staging.dbo.pedido p
inner join staging.dbo.detalle_pedido dp 
on p.codigo_pedido=dp.codigo_pedido
left join staging.dbo.cliente cl 
on cl.codigo_cliente=p.codigo_cliente