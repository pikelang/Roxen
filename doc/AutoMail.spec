// Client Layer functions

int authentificate_user(string username, string passwordcleartext)
mapping(string:int) list_mailboxes(int user)
array(int) list_mail(int user, int mailbox_id)
mapping(string:mixed) retrieve_mail(int mail_id)
array(string) retrieve_mail_headers(int message_id)
int delete_mail(int mail_id)
int create_mailbox(int user, string mailbox)
string get_mailbox_name(int mailbox_id)
int delete_mailbox(int mailbox_id)
int rename_mailbox(int mailbox_id, string newmailbox)
int add_mailbox_to_mail(int mail_id, int mailbox_id)
void set_flag(int mail_id, string flag)
void remove_flag(int mail_id, string flag)
multiset get_flags(int mail_id)

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
             username		     varchar(128),
	     password		     varchar(8),
             customer_id	     int
     );


create table flags (
             mail_id                 int,
	     name                    varchar(16)
     );








	 
  +------+  +------+  +------+  +------+  +------+ +-----------+
  |      |  | SMTP |  |      |  |      |  |      | |           | 
  | SMTP |  | (in) |  | POP  |  | IMAP |  | FAX  | | Webclient |
  | (ut) |  |Filter|  |      |  |      |  | SMS  | |           |
  +------+  +------+  +------+  +------+  +------+ +-----------+
      ^	       	|      	  ^    	    ^  	      ^		|^      
      |         |         |         |         |         ||
      |         |         |         |         |         ||
      |	        v      	  |    	    |  	      |	       	v|   
  +------------------------------------------------------------+
  |				        		       |
  |    	       	        AutoMailAPI                            |
  |			                		       |
  +------------------------------------------------------------+
			    |    ^      			
	                    v    |                              
             +-----------------------------------+
             | +-----------------------------------+ 
             | | +-----------------------------------+
	     | | | 		        	     |
             | | |            Mail DB   	     |
	     | | |              		     |
	     | | |      (MESSAGES, MAILBOXES)        |    
	     | | |      		             |    
	     | | |   (Ska ses som en abstrakt repr., |
	     | | |    implementeras med en enda      |
	     +-| |    MESSAGES-, resp. MAILBOXES-    |
	       +-|    tabell.)                       |
		 +-----------------------------------+
		       (flera MDB:er)                


Tabeller:
---------
MESSAGES
USERS
DOMAINS
CUSTOMERS
MAILBOXES					    
						    
						    
						    