# $Id: db.spec,v 1.1 1998/07/13 00:13:05 js Exp $

drop table clients;
drop table dns;
drop table messages;
drop table mailboxes;
drop table users;

create table clients (
             id	                     int auto_increment primary key,
             user_id                 varchar(64) not null,
	     name		     varchar(255) not null,
	     domain_id		     int,
	     intraseek		     int,
	     logview		     int,
	     sms		     int,
	     fax		     int,
             registration_date       timestamp
     );

create table dns (
             id                      int auto_increment primary key,
             client_id		     int,
             rr_type		     varchar(8),
             rr_value		     varchar(255)
     );
	    
create table messages (
             id	                     int auto_increment primary key,
             sender		     varchar(255),
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
     