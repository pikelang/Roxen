# $Id: db.spec,v 1.6 1998/07/21 05:53:30 js Exp $

drop table customers;
drop table dns;
drop table messages;
drop table mailboxes;
drop table users;

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


create table templates (
             id		             int auto_increment primary key,
             name		     varchar(255),
             filename		     varchar(255)
     );

create table templates_vars (
             name                    varchar(64),
             realname		     varchar(255),
	     help		     blob,
	     type		     varchar(8) # font/color/image
     );

create table nav_templates (
             id		             int auto_increment primary key,
             name		     varchar(255),
             filename		     varchar(255)
     );

create table nav_templates_vars (
             name                    varchar(64),
             realname		     varchar(255),
	     help		     blob,
	     type		     varchar(8) # font/color/image
     );

create table color_schemes (
	     colorscheme_id	     int,
	     name		     varchar(64),
	     value		     varchar(255)
     );
     