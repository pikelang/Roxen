# $Id: db.spec,v 1.23 1998/09/12 12:55:10 per Exp $

drop table messages;
drop table mail;
drop table mailboxes;
drop table users;
drop table customers;
drop table dns;
drop table template_wizards;
drop table template_wizards_pages;
drop table template_vars;
drop table template_option_groups;
drop table template_options;
drop table template_schemes;
drop table template_schemes_vars;
drop table customers_schemes;
drop table customers_schemes_vars;

# AutoMail

create table mail_misc (
	     id			bigint not null primary key,
	     variable 		varchar(16) not null primary key,
	     value		varchar(255),
 );

create table user_misc (
	     id			bigint not null primary key,
	     variable 		varchar(16) not null primary key,
	     value		varchar(255),
 );


create table message_body_id (
	     last		bigint
  );

create table messages (
             id	                     bigint auto_increment primary key,
             sender		     varchar(255),
             subject                 varchar(255),
	     body_id		     varchar(32),
	     refcount		     int,
	     headers		     blob,
	     incoming_date	     timestamp
     );

create table mail (
             id	                     bigint auto_increment primary key,
	     mailbox_id		     int,
             message_id		     bigint
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


create table admin_status (
             user_id                 int,
	     rcpt_name		     varchar(64),
             status                  varchar(1)
     );

          
create table admin_variables (
             user_id                 int not null,
	     rcpt_name		     varchar(64) not null,
	     name		     varchar(64) not null,
	     value		     varchar(255),
	     PRIMARY KEY(user_id,rcpt_name,name)
     );
	     
	     
// Domäner? Koppling till den andra databasen?

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
	    
# AutoWeb

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
             help		     blob,
             example_html            blob
     );

# Template variables
create table template_vars (
	     id                      int auto_increment primary key,
             name                    varchar(64) not null,
             title		     varchar(255),
	     page_id                 int not null,
             help		     blob,
	     type		     varchar(8), # font/color/image/select
             option_group_id         int
     );

# Template variables option groups
create table template_option_groups (
             id                      int auto_increment primary key,
             name                    varchar(64) not null
     );

# Template variables options
create table template_options (
             id		             int auto_increment primary key,
	     option_group_id	     int not null,
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
