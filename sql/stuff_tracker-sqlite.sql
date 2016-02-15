
create table status(
    status_id integer primary key,
    description varchar(50) not null
);

create table db_column_type(
    db_column_type_id integer primary key,
    name varchar(25) not null,
    description varchar(25) not null
);

create table db_column(
    db_column_id integer primary key,
    name varchar(50) not null,
    description varchar(50) not null,
    column_size int4 not null DEFAULT 100,
    column_order int4 not null DEFAULT 1,
    db_column_type_to_db_column_id int4 not null DEFAULT 1,
    status_to_db_column_id int4 not null DEFAULT 1,
    FOREIGN KEY (db_column_type_to_db_column_id) REFERENCES db_column_type (db_column_type_id),
    FOREIGN KEY (status_to_db_column_id) REFERENCES status (status_id)
);

create table stuff_tracker(
    stuff_tracker_id integer primary key,
    created timestamp not null,
    updated timestamp null
);

insert into status (description) values ('ACTIVE');
insert into status (description) values ('INACTIVE');

insert into db_column_type (name,description) values ('varchar','Text');
insert into db_column_type (name,description) values ('date','Date');
insert into db_column_type (name,description) values ('select','Select');
insert into db_column_type (name,description) values ('integer','Integer');

insert into db_column (name,description,db_column_type_to_db_column_id) values ('integrated_by','Integrated By',(select db_column_type_id from db_column_type where name = 'integer'));
alter table stuff_tracker add column integrated_by int4 null;

insert into db_column (name,description,db_column_type_to_db_column_id) values ('updated_by','Updated By',(select db_column_type_id from db_column_type where name = 'integer'));
alter table stuff_tracker add column updated_by int4 null;

--
-- samples
--

-- varchar sample
insert into db_column (name,description,db_column_type_to_db_column_id) values ('column_1','Sample Text Column',(select db_column_type_id from db_column_type where name = 'varchar'));
alter table stuff_tracker add column column_1 varchar(100) null;

-- date sample
insert into db_column (name,description,db_column_type_to_db_column_id) values ('column_2','Sample Date Column',(select db_column_type_id from db_column_type where name = 'date'));
alter table stuff_tracker add column column_2 timestamp null;

-- select sample
insert into db_column (name,description,db_column_type_to_db_column_id) values ('column_3','Sample Select Column',(select db_column_type_id from db_column_type where name = 'select'));

create table column_3 (
    column_3_id integer primary key,
    description varchar(100) not null,
    status_to_column_3_id int4 not null DEFAULT 1,
    FOREIGN KEY (status_to_column_3_id) REFERENCES status (status_id)
);

insert into column_3 (description) values ('First Option');
insert into column_3 (description) values ('Second Option');
insert into column_3 (description) values ('Third Option');

alter table stuff_tracker add column column_3_to_stuff_tracker_id int4 null DEFAULT 1;

-- Add Constraints to stuff_tracker table (SQLite)
create temporary table stuff_tracker_backup AS select * from stuff_tracker;

drop table stuff_tracker;

create table stuff_tracker(
    stuff_tracker_id integer primary key,
    created timestamp not null,
    updated timestamp null,
    integrated_by int4 null,
    updated_by int4 null,
    column_1 varchar(100) null,
    column_2 timestamp null,
    column_3_to_stuff_tracker_id int4 null default 1,
    FOREIGN KEY (column_3_to_stuff_tracker_id) REFERENCES column_3 (column_3_id)
);

insert into stuff_tracker select * from stuff_tracker_backup;

drop table stuff_tracker_backup;
