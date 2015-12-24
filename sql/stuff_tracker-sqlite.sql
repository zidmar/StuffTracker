
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

insert into db_column (description,db_column_type_to_db_column_id) values ('sample_text_column',(select db_column_type_id from db_column_type where name = 'varchar'));

alter table stuff_tracker add column sample_text_column varchar(100) null;

insert into db_column (description,db_column_type_to_db_column_id) values ('sample_date_column',(select db_column_type_id from db_column_type where name = 'date'));

alter table stuff_tracker add column sample_date_column timestamp null;

insert into db_column (description,db_column_type_to_db_column_id) values ('sample_select_column',(select db_column_type_id from db_column_type where name = 'select'));

create table sample_select_column (
    sample_select_column_id integer primary key,
    description varchar(100) not null,
    status_to_sample_select_column_id int4 not null DEFAULT 1,
    FOREIGN KEY (status_to_sample_select_column_id) REFERENCES status (status_id)
);

insert into sample_select_column (description) values ('First Option');

alter table stuff_tracker add column sample_select_column_to_stuff_tracker_id int4 null default 1;

create temporary table stuff_tracker_backup AS select * from stuff_tracker;

drop table stuff_tracker;

create table stuff_tracker(
    stuff_tracker_id integer primary key,
    created timestamp not null,
    updated timestamp null,
    sample_text_column varchar(100) null,
    sample_date_column timestamp null,
    sample_select_column_to_stuff_tracker_id int4 null default 1,
    FOREIGN KEY (sample_select_column_to_stuff_tracker_id) REFERENCES sample_select_column (sample_select_column_id)
);

insert into stuff_tracker select * from stuff_tracker_backup;

drop table stuff_tracker_backup;
