# $Id: db.spec,v 1.12 1998/07/27 17:13:26 wellhard Exp $

drop table customers;
drop table dns;
drop table messages;
drop table mailboxes;
drop table users;
drop table customers_preferences;
drop table template_wizards;
drop table template_vars;
drop table template_vars_opts;
drop table template_schemes;
drop table template_schemes_vars;
drop table customers_files;
drop table customers_menu;
drop table customers_md;


create table customers (
             id	                     int auto_increment primary key,
             user_id                 varchar(64) not null,
	     password		     varchar(64) not null,
	     name		     varchar(255) not null,
	     intraseek		     int,
	     logview		     int,
	     sms		     int,
	     fax		     int,
             registration_date       timestamp
     );

create table dns (
             id                      int auto_increment primary key,
             customer_id             int,
	     domain		     varchar(255),
	     rr_owner		     varchar(255),
             rr_type		     varchar(8),
             rr_value		     varchar(255)
     );
	    
create table messages (
             id	                     int auto_increment primary key,
             sender		     varchar(255),
             subject                 varchar(255),
             contents		     blob
     );

create table mailboxes (
             user_id                 int,
             message_id		     int,
             received		     timestamp,
             sent		     timestamp,
             sent_by		     int
     );
 
create table users (
             id		             int auto_increment primary key,
             realname		     varchar(255),
             username		     varchar(64),
             aliasname		     varchar(64),
             customer_id	     int
     );

create table customers_preferences (
	     id                      int auto_increment primary key,
             customer_id             int,
             variable_id             int,
             value                   blob
     );

create table template_wizards (
             id                      int auto_increment primary key,
             name                    varchar(64),
             title                   varchar(255),
             help		     blob,
	     category		     varchar(8)  # tmpl/nav
     );

create table template_vars (
	     id                      int auto_increment primary key,
             name                    varchar(64),
             title		     varchar(255),
	     wizard_id               int,
             help		     blob,
	     type		     varchar(8) # font/color/image/int
     );

create table template_vars_opts (
             id		             int auto_increment primary key,
	     variable_id	     int,
             name		     varchar(255),
             value		     blob
     );
    
create table template_schemes (
             id                      int auto_increment primary key,
	     name                    varchar(64),
	     title		     varchar(255)     
     );

create table template_schemes_vars (
             id                      int auto_increment primary key,
             scheme_id               int,
	     variable_id	     int,
	     value		     blob
     );

create table customers_files (
	     id			     int auto_increment primary key,
             customer_id             int,
             filename                varchar(255)
     );

create table customers_menu (
	     id			     int auto_increment primary key,
	     customer_id             int,
             file_id                 int,
	     item_order              int,
 	     title                   varchar(255)
     );
