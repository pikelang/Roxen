# $Id: db.spec,v 1.19 1998/09/04 14:01:29 wellhard Exp $

drop table messages;
drop table mail;
drop table mailboxes;
drop table users;
drop table customers;
drop table dns;
drop table template_wizards;
drop table template_wizards_pages;
drop table template_vars;
drop table template_vars_opts;
drop table template_schemes;
drop table template_schemes_vars;
drop table customers_schemes;
drop table customers_schemes_vars;

# AutoMail

create table messages (
             id	                     int auto_increment primary key,
             sender		     varchar(255),
             subject                 varchar(255),
	     body_id		     varchar(32),
	     refcount		     int,
	     headers		     blob,
	     incoming_date	     timestamp
     );

create table mail (
             id	                     int auto_increment primary key,
	     mailbox_id		     int,
             message_id		     int
     );

     
create table mailboxes (
             id	                     int auto_increment primary key,	
             user_id                 int,
	     name		     varchar(64)
     );
 
create table users (
             id		             int auto_increment primary key,
             realname		     varchar(255),
             username		     varchar(64),
	     password		     varchar(13),
             customer_id	     int
     );

create table flags (
             mail_id                 int,
	     name                    varchar(16)
     );

# AutoAdmin         

create table customers (
             id	                     int auto_increment primary key,
             user_id                 varchar(64) not null,
	     password		     varchar(64) not null,
	     name		     varchar(255) not null,
	     intraseek		     int,
	     logview		     int,
	     sms		     int,
	     fax		     int,
             registration_date       timestamp,
             template_scheme_id      int not null default 1,
     );

create table dns (
             id                      int auto_increment primary key,
             customer_id             int,
	     domain		     varchar(255),
	     rr_owner		     varchar(255),
             rr_type		     varchar(8),
             rr_value		     varchar(255)
     );
	    

# Template wizards
create table template_wizards (
             id                      int auto_increment primary key,
             name                    varchar(64),
             title                   varchar(255),
             help		     blob,
	     category		     varchar(8)  # tmpl/nav
     );

# Tempate wizards pages
create table template_wizards_pages (
             id                      int auto_increment primary key,
             name                    varchar(64),
             title                   varchar(255),
             wizard_id               int,
             help		     blob
     );

# Template variables
create table template_vars (
	     id                      int auto_increment primary key,
             name                    varchar(64),
             title		     varchar(255),
	     page_id                 int,
             help		     blob,
	     type		     varchar(8) # font/color/image/int
     );

# Template variables options
create table template_vars_opts (
             id		             int auto_increment primary key,
	     variable_id	     int,
             name		     varchar(255),
             value		     blob
     );

# Template schemes
create table template_schemes (
             id                      int auto_increment primary key,
	     name                    varchar(64),
	     description             blob
     );

# Template schemes variables
create table template_schemes_vars (
             id                      int auto_increment primary key,
             scheme_id               int,
	     variable_id	     int,
	     value		     blob
     );

# Customers schemes
create table customers_schemes (
             id                      int auto_increment primary key,
	     customer_id             int,
	     name                    varchar(64),
	     description	     blob
     );

# Customers schemes variables
create table customers_schemes_vars (
             id                      int auto_increment primary key,
             scheme_id               int,
	     variable_id	     int,
	     value		     blob
     );
