# $Id: db.spec,v 1.33 1998/09/22 19:51:37 wellhard Exp $

drop table mail_misc;
drop table user_misc;
drop table message_body_id;
drop table messages;
drop table mail;
drop table mailboxes;
drop table send_q;
drop table users;
drop table flags;
drop table admin_status;
drop table admin_variables;
drop table customers;
drop table features;
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
             id                bigint not null,
             variable          varchar(16) not null,
             qwerty            blob not null,
             PRIMARY KEY(id,variable)
  );

create table user_misc (
             id                 bigint not null,
             variable           varchar(16) not null,
             qwerty             blob not null,
             PRIMARY KEY(id,variable)
 );


create table message_body_id (
             last               bigint
  );

create table messages (
             id                  bigint auto_increment primary key,
             sender              varchar(255) not null,
             subject             varchar(255) not null,
             body_id             varchar(32) not null,
             refcount            int not null,
             headers             blob not null,
             incoming_date       timestamp not null
     );

create table mail (
             id                  bigint auto_increment primary key,
             mailbox_id          int not null,
             message_id          bigint not null,
             INDEX mail_index (mailbox_id)
     );

     
create table mailboxes (
             id                      int auto_increment primary key,    
             user_id                 int not null,
             name                    varchar(64) not null,
	     INDEX user_index (user_id)
     );

create table send_q (
             id                      int auto_increment primary key,
             sender                  varchar(255) not null,
             user                    varchar(255) not null,
             domain                  varchar(255) not null,
             mailid                  varchar(32) not null,
             received_at             int not null,
             send_at                 int not null,
             times                   int not null,
	     remoteident	     varchar(255) not null,
	     remoteip		     varchar(32) not null,
	     remotename		     varchar(255) not null
     );
 
create table users (
             id                      int auto_increment primary key,
             realname                varchar(255) not null,
             username                varchar(64) not null,
             password                varchar(13) not null,
             customer_id             int not null
     );

create table flags ( 
             mail_id                 int not null,
             name                    varchar(16) not null,
             INDEX flag_index (mail_id)
     );


create table admin_status (
             user_id                 int not null,
             rcpt_name               varchar(64) not null,
             status                  varchar(1) not null default '0'
     );

          
create table admin_variables (
             user_id                 int not null,
             rcpt_name               varchar(64) not null,
             name                    varchar(64) not null,
             value                   varchar(255),
             PRIMARY KEY(user_id,rcpt_name,name)
     );
             
# AutoAdmin         

create table customers (
             id                      int auto_increment primary key,
             user_id                 varchar(64) not null,
             password                varchar(64) not null,
             name                    varchar(255) not null,
             registration_date       timestamp,
             template_scheme_id      int not null,
             UNIQUE(template_scheme_id)
     );

create table dns (
             id                      int auto_increment primary key,
             customer_id             int,
             domain                  varchar(255),
             rr_owner                varchar(255),
             rr_type                 varchar(8),
             rr_value                varchar(255)
     );

create table features (
             customer_id             int not null,
             feature                 varchar(64) not null,
             PRIMARY KEY(customer_id,feature)
     );
  
create table features_list (
             feature                 varchar(64)
     );
  

# AutoWeb

# Template wizards
CREATE TABLE template_wizards (
             id                      INT NOT NULL AUTO_INCREMENT,
             name                    VARCHAR(64) NOT NULL,
             title                   VARCHAR(255) NOT NULL,
             help                    BLOB,
             category                VARCHAR(8) NOT NULL,  # tmpl/nav
             PRIMARY KEY(id)
     );

# Tempate wizards pages
CREATE TABLE template_wizards_pages (
             id                      INT NOT NULL AUTO_INCREMENT,
             name                    VARCHAR(64) NOT NULL,
             title                   VARCHAR(255),
             wizard_id               INT NOT NULL,
             help                    BLOB,
             example_html            BLOB,
             PRIMARY KEY(id)
     );

# Template variables
CREATE TABLE template_vars (
             id                      INT NOT NULL AUTO_INCREMENT,
             name                    VARCHAR(64) NOT NULL,
             title                   VARCHAR(255) NOT NULL,
             page_id                 INT NOT NULL,
             help                    BLOB,
             type                    VARCHAR(64) NOT NULL,
             option_group_id         INT,
             PRIMARY KEY(id)
     );

# Template variables option groups
CREATE TABLE template_option_groups (
             id                      INT NOT NULL AUTO_INCREMENT,
             name                    VARCHAR(64) NOT NULL,
             PRIMARY KEY(id)
     );

# Template variables options
CREATE TABLE template_options (
             id                      INT NOT NULL AUTO_INCREMENT,
             option_group_id         INT NOT NULL,
             name                    VARCHAR(255) NOT NULL,
             value                   BLOB,
             PRIMARY KEY(id)
     );

# Template schemes
CREATE TABLE template_schemes (
             id                      INT NOT NULL AUTO_INCREMENT,
             name                    VARCHAR(64) NOT NULL,
             description             BLOB,
             PRIMARY KEY(id)
     );

# Template schemes variables
CREATE TABLE template_schemes_vars (
             id                      INT NOT NULL AUTO_INCREMENT,
             scheme_id               INT NOT NULL,
             variable_id             INT NOT NULL,
             value                   BLOB,
             PRIMARY KEY(id),
             UNIQUE(scheme_id, variable_id)
     );

# Customers schemes
create table customers_schemes (
             id                      INT NOT NULL AUTO_INCREMENT,
             customer_id             INT,
             name                    VARCHAR(64) NOT NULL,
             description             BLOB,
             PRIMARY KEY(id)
     );

# Customers schemes variables
CREATE TABLE customers_schemes_vars (
             id                      INT NOT NULL AUTO_INCREMENT,
             scheme_id               INT NOT NULL,
             variable_id             INT NOT NULL,
             value                   BLOB,
             PRIMARY KEY(id),
             UNIQUE(scheme_id, variable_id)
     );
