// This is a roxen module.

// A WAIS proxy module, not written by anyone at Infovav, and it would
// seem that I have forgotten who wrote it.


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#include <config.h>

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DEF_CONNECTION_REFUSED "HTTP/1.0 500 Connection refused by remote host\r\nContent-type: text/html\r\n\r\n<title>Roxen error: Connection refused</title>\n<h1>Proxy request failed</h1><hr><font size=+2><i>Connection refused by remote host</i></font><hr><font size=-2><a href=http://roxen.com/>Roxen</a></font>"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define CONNECTION_REFUSED   QUERY(ConnRefuse)



/* #define WAIS_DEBUG define this to have lot of debug */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#if DEBUG_LEVEL > 22
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
# ifndef WAIS_DEBUG
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#  define WAIS_DEBUG
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
# endif
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define bitsPerByte	    8
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define HEADER_LEN	    2 
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define BINARY_INTEGER_BYTES      4

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define UNUSED	-1


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define HEADER_LENGTH 	25	/* number of bytes needed to write a wais-header (not sizeof(wais_header)) */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define HEADER_VERSION 	"2"

/* message type */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define Z3950		"z"  
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ACK		"a"  
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	NAK		"n"  

/* compression */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define NO_COMPRESSION 		" " 
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define UNIX_COMPRESSION 	"u" 

/* encoding */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define NO_ENCODING	" "  
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define HEX_ENCODING	"h"  /* Swartz 4/3 encoding */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define IBM_HEXCODING	"i"  /* same as h but uses characters acceptable for IBM mainframes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define UUENCODE	"u"  




string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DB_DELIMITER 	"\037" 	/* hex 1F occurs between each database name */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DELIMITER_1 	"\037" 	/* separates database name from element name */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DELIMITER_2 	"\036" 	/* hex 1E separates <db,es> groups from one another */


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define QT_BooleanQuery	                "1"		/* standard boolean query */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define QT_RelevanceFeedbackQuery	"3"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define QT_TextRetrievalQuery		QT_BooleanQuery


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define IGNORE	                        "ig"

/* use value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	UV_ISBN                        	"ub"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	CORPORATE_NAME                	"uc"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	ISSN	                        "us"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	PERSONAL_NAME	                "up"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	SUBJECT                        	"uj"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	TITLE	                        "ut"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	GEOGRAPHIC_NAME                	"ug"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	CODEN	                        "ud"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	SUBJECT_SUBDIVISION	        "ue"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	SERIES_TITLE	                "uf"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	MICROFORM_GENERATION	        "uh"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	PLACE_OF_PUBLICATION	        "ui"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	NUC_CODE	                "uk"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	LANGUAGE	                "ul"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	COMBINATION_OF_USE_VALUES	"um"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	SYSTEM_CONTROL_NUMBER	        "un"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DATE	                        "uo"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	LC_CONTROL_NUMBER	        "ur"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	MUSIC_PUBLISHERS_NUMBER        	"uu"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	GOVERNMENT_DOCUMENTS_NUMBER	"uv"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	SUBJECT_CLASSIFICATION	        "uw"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	RECORD_TYPE	                "uy"

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DATA_TYPE                       "wt"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define BYTE                            "wb"

/* relation value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	EQUAL	                "re"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	GREATER_THAN	        "rg"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	GREATER_THAN_OR_EQUAL	"ro"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	LESS_THAN	        "rl"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	LESS_THAN_OR_EQUAL	"rp"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	NOT_EQUAL	        "rn"

/* position value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	FIRST_IN_FIELD	        "pf"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	FIRST_IN_SUBFIELD	"ps"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	FIRST_IN_A_SUBFIELD	"pa"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	FIRST_IN_NOT_A_SUBFIELD	"pt"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	ANY_POSITION_IN_FIELD	"py"

/* structure value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	PHRASE	                "sp"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	WORD	                "sw"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	KEY	                "sk"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	WORD_LIST	        "sl"

/* truncation value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	NO_TRUNCATION	                "tn"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	RIGHT_TRUNCATION	        "tr"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	PROC_NUM_INCLUDED_IN_SEARCH_ARG	"ti"

/* completeness value codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	INCOMPLETE_SUBFIELD	"ci"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	COMPLETE_SUBFIELD	"cs"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	COMPLETEFIELD	        "cf"

/* operator codes */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define AND	"a"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define OR	"o"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define AND_NOT	"n"

/* term types */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define TT_Attribute		1
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	TT_ResultSetID		2
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	TT_Operator		3

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ATTRIBUTE_SIZE          3
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define OPERATOR_SIZE	        2
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define AT_DELIMITER            " "


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	initAPDU			20
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	initResponseAPDU		21
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	searchAPDU			22
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	searchResponseAPDU		23
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	presentAPDU			24
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	presentResponseAPDU		25
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	deteteAPDU			26
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	deleteResponseAPDU		27
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	accessControlAPDU		28
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	accessControlResponseAPDU	29
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	resourceControlAPDU		30
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	resourceControlResponseAPDU	31



string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_PDUType			1 	
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ReferenceID			2
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ProtocolVersion		3
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Options			4
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_PreferredMessageSize		5
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_MaximumRecordSize		6
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_IDAuthentication		7
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ImplementationID		8
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ImplementationName		9
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ImplementationVersion	10
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_UserInformationField		11
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Result			12
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SmallSetUpperBound		13
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_LargeSetLowerBound		14
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_MediumSetPresentNumber	15
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ReplaceIndicator		16
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultSetName		17
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DatabaseNames		18
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ElementSetNames 		19
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_QueryType			20
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Query			21
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SearchStatus			22
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultCount			23
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_NumberOfRecordsReturned	24
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_NextResultSetPosition	25
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultSetStatus		26
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_PresentStatus		27
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DatabaseDiagnosticRecords	28
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_NumberOfRecordsRequested	29
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultSetStartPosition	30
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultSetID			31
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DeleteOperation		32
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DeleteStatus			33
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_NumberNotDeleted		34
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_BulkStatuses			35
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DeleteMSG			36
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SecurityChallenge		37
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SecurityChallengeResponse	38
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SuspendedFlag		39
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResourceReport		40
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_PartialResultsAvailable	41
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ContinueFlag			42
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ResultSetWanted		43
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_AttributeList	        44
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_Term			        45
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_Operator		        46

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_UserInformationLength	99
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ChunkCode			100
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ChunkIDLength		101
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ChunkMarker			102
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_HighlightMarker		103
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DeHighlightMarker		104
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_NewlineCharacters		105
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SeedWords			106
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DocumentIDChunk		107
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ChunkStartID			108
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_ChunkEndID			109
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_TextList			110
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DateFactor			111
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_BeginDateRange		112
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_EndDateRange			113
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_MaxDocumentsRetrieved	114
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_SeedWordsUsed		115
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DocumentID			116
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_VersionNumber		117
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Score			118
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_BestMatch			119
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DocumentLength		120
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Source			121
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Date				122
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_Headline			123
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_OriginCity			124
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_PresentStartByte		125
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_TextLength			126
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_DocumentText			127
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_StockCodes			128
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_CompanyCodes			129
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_IndustryCodes		130

/* added by harry */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentHeaderGroup		150
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentShortHeaderGroup	151
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentLongHeaderGroup	152
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentTextGroup		153
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentHeadlineGroup 	154
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_DocumentCodeGroup		155
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_Lines			131 
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define	DT_TYPE_BLOCK			132
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define DT_TYPE				133


string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentHeader	"Document Header"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentShortHeader	"Document Short Header"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentLongHeader	"Document Long Header"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentText		"Document Text"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentHeadline	"Document Headline"
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define ES_DocumentCodes	"Document Codes"

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define continueBit	128
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define dataMask	127
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define dataBits	7
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define CompressedInt1Byte	128 		/* 2 ^ 7 */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define CompressedInt2Byte	16384 		/* 2 ^ 14 */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#define CompressedInt3Byte	2097152 	/* 2 ^ 21 */


inherit "module";
inherit "socket";
inherit "roxenlib";

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#include <module.h>
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#include "base_server/proxyauth.pike"



string debug_print_string(string str)
{
  int i;
  string out,t;

  out="";
  for(i=0;i<sizeof(str); i++) {
    t=str[i..i];
    if(search("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./-_$:;,\"",t)==-1) {
      out += sprintf("<%d>",t[0]);
    } else
      out += t;
  }
  return out;
}



string trim_junk(string headline)
{
  int length;
  int i,j;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("trim_junk1("+debug_print_string(headline)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  headline = replace(headline, ({ "\033(", "\033)"}) , ({"",""}));

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("trim_junk2("+debug_print_string(headline)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  while((i=search(headline,"\033"))!=-1)
    headline=headline[0..i]+headline[i+4..1000000];

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("trim_junk3("+debug_print_string(headline)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  while(strlen(headline)>0 && headline[0]==' ')
    headline=headline[1..1000000];

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("trim_junk4("+debug_print_string(headline)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

/*  headline=headline/"\n";

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("trim_junk5("+debug_print_string(headline)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
*/

  return headline;
}


array register_module()
{
  return ({ 
    MODULE_LOCATION|MODULE_PROXY,
    "Wais Gateway",
    "This is a caching wais gateway, useful for firewall sites and "
      "for everyone who wants to aquire better 'surfing speed'.", ({}), 1
    });
}

string query_location() { return query("loc"); }

void create()
{
  defvar("loc", "wais:/", "Location", TYPE_LOCATION,
	 "The mountpoint of the wais gateway");
  defvar("cache", 0, "Cache wais files", TYPE_FLAG,
	 "This will enable the cacheing of wais files; actually cacheing "
	 "is experimental.");
  defvar("ConnRefuse", DEF_CONNECTION_REFUSED,
	 "Connection Refused message", TYPE_TEXT_FIELD,
	 "Here you can set the HTML file returned to report a connection"
	 "refused error to the gateway user.");
}




int getCompressedBinIntSize(int num)
{
  if (num < 0)
    return(4);
  else if (num < 256)		/* 2**8 */
    return(1);
  else if (num < 65536)	/* 2**16 */
    return(2);
  else if (num < 16777216)	/* 2**24 */
    return(3);
  else
    return(4);
}


string writeCompressedInteger(int num)
{
  string buf;

  if (num < CompressedInt1Byte) {
    buf=sprintf("%c",num&dataMask);
  }
  else if (num < CompressedInt2Byte) {
    buf=sprintf("%c%c",((num>>(dataBits))&dataMask)|continueBit,num&dataMask);
  }
  else if (num < CompressedInt3Byte) {
    buf=sprintf("%c%c%c",((num>>(dataBits*2))&dataMask)|continueBit,
		((num>>(dataBits))&dataMask)|continueBit,num&dataMask);
  }
  else {
    buf=sprintf("%c%c%c%c",((num>>(dataBits*3))&dataMask)|continueBit,
		((num>>(dataBits*2))&dataMask)|continueBit,
		((num>>(dataBits))&dataMask)|continueBit,num&dataMask);
  }

  return buf;
} 

string writeString(string s,int tag)
{
  string buf;

  buf = writeCompressedInteger(tag);
  buf += writeCompressedInteger(strlen(s));
  buf += s;

  return buf;
}


string writeBinaryInteger(int num,int size)
{
  string buf;

  switch(size) {
  case 1:
    buf=sprintf("%c",num&255);
    break;
  case 2:
    buf=sprintf("%c%c",(num>>(bitsPerByte))&255,num&255);
    break;
  case 3:
    buf=sprintf("%c%c%c",(num>>(bitsPerByte*2))&255,
		(num>>(bitsPerByte))&255,num&255);
    break;
  case 4:
    buf=sprintf("%c%c%c%c",(num>>(bitsPerByte*3))&255,
		(num>>(bitsPerByte*2))&255,(num>>(bitsPerByte))&255,num&255);
    break;
  default:
    perror(sprintf("Invalid writeBinaryInteger call: num %d, size &d\n",
		   num,size));
    buf="";
  }
  return buf;
}


string writeByte(int byte)
{
  return sprintf("%c",byte);
}



string generate_search_apdu(string seed_words, string database,
			    int maxDocsRetrieved)
{
  string buf,nbuf;

  buf = writeBinaryInteger(searchAPDU,1);
  buf += writeBinaryInteger(30,3);
  buf += writeBinaryInteger(5000,3);
  buf += writeBinaryInteger(30,3);
  buf += writeByte(1);
  buf += writeString("",DT_ResultSetName);
  buf += writeString(database,DT_DatabaseNames);
  buf += writeString(QT_RelevanceFeedbackQuery,DT_QueryType);

  /*  buf += writeString(" "+ES_DELIMITER_1+ES_DocumentText,
      DT_ElementSetNames); */

  buf += writeString("3",DT_ReferenceID);

  /* go back and write the header-length-indicator */

  nbuf=writeBinaryInteger(sizeof(buf),HEADER_LEN)+buf;

  /* now write search info */

  buf = writeString(seed_words,DT_SeedWords);

  buf += writeCompressedInteger(DT_DateFactor);
  buf += writeCompressedInteger(1); 
  buf += writeBinaryInteger(1,1); 

  buf += writeString("0",DT_BeginDateRange);
  buf += writeString("0",DT_EndDateRange);

  buf += writeCompressedInteger(DT_MaxDocumentsRetrieved);
  buf += writeCompressedInteger(getCompressedBinIntSize(maxDocsRetrieved)); 
  buf += writeBinaryInteger(maxDocsRetrieved,
			    getCompressedBinIntSize(maxDocsRetrieved)); 

  /* write tag and size */

  nbuf += writeCompressedInteger(DT_UserInformationLength);
  nbuf += writeCompressedInteger(sizeof(buf))+buf;

  return nbuf;
}


string generate_retrieval_apdu(string docid, string doctype, string database)
{
  int start,end;
  string buf,nbuf,attributes,query;

  start=0;end=10000;

  if(!doctype) 
    doctype="TEXT";

  /* write search packet */

  buf = writeBinaryInteger(searchAPDU,1);
  buf += writeBinaryInteger(10,3);
  buf += writeBinaryInteger(16,3);
  buf += writeBinaryInteger(15,3);
  buf += writeByte(1);
  buf += writeString("FOO",DT_ResultSetName);
  buf += writeString(database,DT_DatabaseNames);
  buf += writeString(QT_TextRetrievalQuery,DT_QueryType);
  buf += writeString(" "+ES_DELIMITER_1+ES_DocumentText,DT_ElementSetNames);
  buf += writeString("3",DT_ReferenceID);
 
  /* go back and write the header-length-indicator */

  nbuf=writeBinaryInteger(sizeof(buf),HEADER_LEN)+buf;


  /* now write the query */

  query = writeString(SYSTEM_CONTROL_NUMBER+AT_DELIMITER+EQUAL+AT_DELIMITER+
		      IGNORE+AT_DELIMITER+IGNORE+AT_DELIMITER+IGNORE+
		      AT_DELIMITER+IGNORE,DT_AttributeList);
  query += writeString(docid,DT_Term);

  query += writeString(DATA_TYPE+AT_DELIMITER+EQUAL+AT_DELIMITER+IGNORE+
		      AT_DELIMITER+IGNORE+AT_DELIMITER+IGNORE+AT_DELIMITER+
		      IGNORE,DT_AttributeList);
  query += writeString(doctype,DT_Term);

  query += writeString(AND,DT_Operator);

  query += writeString(BYTE+AT_DELIMITER+GREATER_THAN_OR_EQUAL+AT_DELIMITER+
		       IGNORE+AT_DELIMITER+IGNORE+AT_DELIMITER+IGNORE+
		       AT_DELIMITER+IGNORE,DT_AttributeList);
  query += writeString(sprintf("%d",start),DT_Term);

  query += writeString(AND,DT_Operator);

  query += writeString(BYTE+AT_DELIMITER+LESS_THAN+AT_DELIMITER+IGNORE+
		       AT_DELIMITER+IGNORE+AT_DELIMITER+IGNORE+AT_DELIMITER+
		       IGNORE,DT_AttributeList);
  query += writeString(sprintf("%d",end),DT_Term);

  query += writeString(AND,DT_Operator);

  nbuf+=writeString(query,DT_Query);

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("generate_retrieval_apdu got:\n"+nbuf+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  return nbuf;
}



/*	Transform file identifier into WWW address
 *	------------------------------------------
 *
 *
 * On exit,
 *	returns		nil if error
 *			string if ok
 */

string WWW_from_archie(string file)
{
  int i,q;
  string res;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("archie id (to become WWW id): "+file+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  for(i=0; i<strlen(file) && file[i]>' '; i++)
    ;

  q=search(file[0..i],":");
  if(q!=-1)
    res="file://"+file[0..q]+file[q+2..i-1];
  else
    res="file://"+file[0..i];

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("archie id (to become WWW id) result: "+res+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  return res;
}


/*	Transform URL into WAIS document identifier
 *	-------------------------------------------
 *
 * On entry,
 *	docname		points to valid name produced originally by
 *			WWW_from_WAIS
 * On exit,
 *	wait docid
 */

string WAIS_from_WWW (string docname)
{
  string z,t2;
  int len,type,tmp,i,j;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("WWW id (to become WAIS id): "+debug_print_string(docname)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  z="";
  while(strlen(docname)>0) {
    if(sscanf(docname,"%d=%s;",type,t2)!=2) {
      if(sscanf(docname,"%d=",type)!=1) {
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	perror("cannot parse record"+docname+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	return 0;
      }
      if(strlen(docname[search(docname,"=")+1..10000])>0) {
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	perror("cannot parse record"+docname+" (second choice)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	return 0;
      }
      t2=sprintf("%c",0);
      docname="";
    }

    docname=docname[search(docname,";")+1..10000];
    len=strlen(t2);

    z+=sprintf("%c",type);

    if (len > 127) {
      tmp = (len / 128);
      len = len - (tmp * 128);
      tmp = tmp + 128;
      z+=sprintf("%c%c",tmp,len);
    } else {
      z+=sprintf("%c",len);
    }
    z+=t2;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    len=strlen(t2);
    perror(sprintf("found record %d, len %d, content %s\n",type,len,t2));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  }

  return z;
}



/*
 *	Transform document identifier into URL
 *	--------------------------------------
 */

string WWW_from_WAIS(string docid)
{
  int in,l,i;
  string out;

  if(!docid)
    return 0;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("WAIS id (to become WWW id): "+debug_print_string(docid)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  out="";
  for(in=0;in<sizeof(docid); ) {
    out+=sprintf("%d",(int)docid[in]);  /* record put type */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror(sprintf("found record type %d\n",(int)docid[in]));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    out+="=";
    in+=1;
    l=docid[in];
    in+=1;
    if (l > 127) {
      l = (l - 128) * 128;
      l = l + docid[in];
      in+=1;
    }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror(sprintf("found record len %d\n",l));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    out += replace(docid[in..in+l-1], ({ "\000", " ", "%" }), 
		   ({"%00", "%20", "%25" }))+";";
    in+=l;
  }

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("translated in "+out+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  return out;
}


/*
 *	Format a plain text record 
 *	---------------------------
 */

string output_text_record(mapping record, int|void binary)
{
  int count;
  string bytes,out;

  if (binary)
    return record->documentText;

  bytes=record->documentText;
  out="";

  replace(bytes,({ "\033(" , "\033)" }) , ({ "",""}));

  for(count = 0; count < sizeof(bytes); count++){
    if(bytes[count] == 27) {
/*
      if('(' == bytes[count + 1] ||
	 ')' == bytes[count + 1])
	count += 1;
      else
*/
      count += 4;
    } else if (bytes[count] == '\n' || bytes[count] == '\r') {
      out+="\n";
    } else {

      /* if ((bytes[count]=='\t') || isprint(bytes[count]))*/ 

      out+=sprintf("%c",bytes[count]);
    } 
  }
  return  out;
}


string showDiags(array (mapping) d)
{
  int i;
  string out;

  out="";

  for (i=0; i<sizeof(d); i++)
    if (strlen(d[i]->ADDINFO)>0)
      out+="Diagnostic code is "+d[i]->DIAG+" "+d[i]->ADDINFO+"\n";
}

/*
 *	Format A Search response for the client
 *	---------------------------------------
 */



string display_search_response(mapping response,string database,
			       string key)
{
  string out;
  int archie,k;
  mapping info;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS........ Displaying search response\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  out=sprintf("Index %s contains the following %d item%s relevant to '%s'.\n",
	      database,response->NumberOfRecordsReturned,
	      response->NumberOfRecordsReturned ==1 ? "" : "s",
	      key);
  out+="The first figure for each entry is its relative score, "
    "the second the number of lines in the item.";


  archie=search(database, "archie")!=-1;	/* Special handling */

  out+="<MENU>";


  info = response->DatabaseDiagnosticRecords;

  if (sizeof(info->Diagnostics)>0) {
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS........ showing diags\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    out+=showDiags(info->Diagnostics);
  }

  if(sizeof(info->DocHeaders)>0) {
    for (k=0; k<sizeof(info->DocHeaders); k++ ) {
      mapping head;
      string headline,docid,docname;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS........ showing header "+sprintf("%d (%d)",k,sizeof(info->DocHeaders))+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

      head=info->DocHeaders[k];

      if(head->headline)
	headline = trim_junk(head->headline);
      else
	headline="";
      docid = info->DocHeaders[k]->docID;

      /* Make a printable string out of the document id. */

      out+="<LI> "+sprintf("%4d  %4d",head->score,head->lines);

      if (archie) {
	string www_name;

	if(www_name = WWW_from_archie(headline))
	  out+="<A HREF=\""+www_name+"\">"+headline+"</A>\n";
	else
	  out+=headline+" (bad file name)";
      } else { /* Not archie */
	docname=WWW_from_WAIS(docid);
	if(docname) {
	  string types_array;

	  types_array="";

	  if(sizeof(head->types)>0) {
	    int i;

	    for (i=0; i<sizeof(head->types); i++) {
	      if(head->types[i]) {
		if(i>0)
		  types_array += ",";
		types_array += replace(head->types[i], ({ "\000", " ", "%" }),
				       ({"%00", "%20", "%25" }));
	      }
	    }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	    perror("WAIS........ Types_array `"+types_array+"'\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  } else
	    types_array+="TEXT";

	  if(sizeof(head->types)>0 && head->types[0]=="URL")
	    out+=" <A HREF=\""+headline+"\">\n";
	  else
	    out+=" <A HREF=\""+replace(database, ({ "\000", " ", "%" }),
				       ({"%00", "%20", "%25" }))+
					 "/"+types_array+
		   sprintf("/%d/",head->DocumentLength)+docname+"\">\n";

	  out+=headline+"</A>\n";
	} else
	  out+="(bad doc id)\n";
      }
    } /* next document header */
  } /* if there were any document headers */
    
  if(sizeof(info->ShortHeaders)>0) {
    for(k =0; k<sizeof(info->ShortHeaders);k++) {
      out+="\n(Short Header record, can't display)\n";
    }
  }
  if(sizeof(info->LongHeaders)>0) {
    for(k =0; k<sizeof(info->LongHeaders);k++) {
      out+="\n(Long Header record, can't display)\n";
    }
  }
  if(sizeof(info->Text)>0) {
    for(k=0; k<sizeof(info->Text); k++) {
      out+="\nText record\n";
      out+=output_text_record(info->Text[k], 0);
    }
  }
  if(sizeof(info->Headlines)>0) {
    for(k=0; k<sizeof(info->Headlines); k++) {
      out+="\n(Headline record, can't display)\n";
    }
  }
  if(sizeof(info->Codes)>0) {
    for(k=0;k<sizeof(info->Codes);k++) {
      out+="\n(Code record, can't display)\n";
    }
  }

  out+="</MENU>\n";

  return out;
}


void my_pipe_done(array (object) a)
{
  if(a[0])
    ::my_pipe_done(a[0]);
}

void write_to_client_and_cache(object client, string data, string key)
{
  object cache;
  object pipe;
  if(query("cache"))
    if(key)
      cache = roxen->create_cache_file("wais", key);

  pipe=Pipe( );
  if(cache)
  {
    pipe->set_done_callback(my_pipe_done, ({ cache, client }));
    pipe->output(cache->file);
  }
  if(client->my_fd)
  {
    pipe->output(client->my_fd);
    pipe->write(data);
  }
}


int readBinaryInteger(int size,string buf)
{
  int i,num;

  if (size < 1 || size > BINARY_INTEGER_BYTES)
    return 0;		/* error */

  num = 0;
  for (i = 0; i < size; i++) {
    num = num << bitsPerByte;
    num += buf[i];
  }
  return num;
}


int readCompressedInteger(string buf)
{
  int num,i;

  num=0;

  i=0;
  while(1) {
    num = num << dataBits;
    num += (buf[i] & dataMask);
    if(!(buf[i] &  continueBit))
      return num;
    i+=1;
  }
} 

int sizeCompressedInteger(string buf)
{
  int num,i;

  num=0;

  i=0;
  while(1) {
    num += 1;
    if(!(buf[i] &  continueBit))
      return num;
    i+=1;
  }
} 

string skipCompressedInteger(string buf)
{
  int i;

  i=0;
  while(1) {
    if(!(buf[i] &  continueBit))
      return buf[i+1..1000000];
    i+=1;
  }
} 



mapping readSearchResponseInfo(string buf)
{
  array (mapping)  docHeaders;
  array (mapping)  shortHeaders;
  array (mapping)  longHeaders;
  array (mapping)  text;
  array (mapping)  headlines;
  array (mapping)  codes;
  array (mapping)  diags;

  int val,size;

  string seedWordsUsed;
  
  diags = ({ });
  docHeaders = ({ });
  shortHeaders = ({ });
  longHeaders = ({ });
  text = ({ });
  headlines = ({ });
  codes = ({ });

  

  /* readUserInfoHeader */

  buf = skipCompressedInteger(buf);
  size = readCompressedInteger(buf);
  buf = skipCompressedInteger(buf);
  buf=buf[0..size-1];

  while (strlen(buf)>0) {
    switch (readCompressedInteger(buf)) {
    case DT_SeedWordsUsed:
      buf = skipCompressedInteger(buf);
      val = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      seedWordsUsed = buf[0..val];
      buf=buf[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_SeedWordsUsed: "+seedWordsUsed+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    case DT_DatabaseDiagnosticRecords:
      int len;
      string diag,addinfo;
      int surrogate;

      buf = skipCompressedInteger(buf);
      len = readBinaryInteger(2,buf);
      buf = buf[2..1000000];

      diag="";
      diag+=buf[0];
      diag+=buf[1];
      if(len>3) {
	addinfo = buf[2..len-1];
	surrogate = buf[len-1];
	buf = buf[len+1..1000000];
      } else {
	surrogate = buf[len-1];
	buf = buf[2..1000000];
      }
      diags += ({ ([ "DIAG" : diag, "ADDINFO" : addinfo, "SURROGATE" : surrogate ]) });
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DatabaseDiagnosticRecords: "+diag+" "+surrogate+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    case DT_DocumentHeaderGroup:
      int versionNumber,score,bestMatch,docLength,lines;
      string docID,source,date,headline,originCity,buf1;
      array (string) types;

      types = ({ });

      /* readWAISDocumentHeader */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DocumentHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      versionNumber = UNUSED;
      score = UNUSED;
      bestMatch = UNUSED;
      docLength = UNUSED;
      lines = UNUSED;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];

      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
	  perror("WAIS: got DT_DocumentID: "+debug_print_string(docID)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Score:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  score = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Score: "+sprintf("%d",score)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_BestMatch:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  bestMatch = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_BestMatch: "+sprintf("%d",bestMatch)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_DocumentLength:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docLength = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentLength: "+sprintf("%d",docLength)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Lines:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  lines = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Lines: "+sprintf("%d",lines)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;

	case DT_TYPE_BLOCK:
	  int size;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_TYPE_BLOCK: \n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

	  buf1 = skipCompressedInteger(buf1);
	  size = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);

	  while (size > 0) {
	    size -= sizeCompressedInteger(buf1);
	    buf1 = skipCompressedInteger(buf1);
	    val = readCompressedInteger(buf1);
	    size -= sizeCompressedInteger(buf1);
	    buf1 = skipCompressedInteger(buf1);
	    types  += ({ buf1[0..val-1] });
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	    perror("WAIS: got DT_TYPE_BLOCK, type: "+buf1[0..val-1]+sprintf(" size is %d, val is %d",size,val)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	    buf1=buf1[val..1000000];
	    size -= val;
	  }
	  break;
	case DT_Source:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  source = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Source: "+source+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Date:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  date = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Date: "+date+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Headline:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  headline = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Headline: "+headline+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_OriginCity:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  originCity = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_OriginCity: "+originCity+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: end DT_DocumentHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      docHeaders += ({ (["versionNumber" : versionNumber,
			 "score" : score,
			 "bestMatch" : bestMatch,
			 "docLength" : docLength,
			 "lines" : lines,
			 "docID" : docID,
			 "types" : types,
			 "source" : source,
			 "date" : date,
			 "headline" : headline,
			 "originCity" : originCity ]) });
      break;
    case DT_DocumentShortHeaderGroup:
      string docID,buf1;
      int versionNumber,score,bestMatch,docLength,lines;
  
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DocumentShortHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

      versionNumber = UNUSED;
      score = UNUSED;
      bestMatch = UNUSED;
      docLength = UNUSED;
      lines = UNUSED;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];
      
      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentID: "+docID+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Score:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  score = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Score: "+sprintf("%d",score)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_BestMatch:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  bestMatch = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_BestMatch: "+sprintf("%d",bestMatch)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_DocumentLength:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docLength = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentLength: "+sprintf("%d",docLength)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Lines:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  lines = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Lines: "+sprintf("%d",lines)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default 2 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: end DT_DocumentShortHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      shortHeaders += ({ (["versionNumber" : versionNumber,
			   "score" : score,
			   "bestMatch" : bestMatch,
			   "docLength" : docLength,
			   "lines" : lines,
			   "docID" : docID ]) });

      break;
    case DT_DocumentLongHeaderGroup:
      int versionNumber,score,bestMatch,docLength,lines;
      string docID,types,source,date,headline,originCity,stockCodes,
      companyCodes,industryCodes,buf1;

      /* readWAISDocumentHeader */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DocumentLongHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      versionNumber = UNUSED;
      score = UNUSED;
      bestMatch = UNUSED;
      docLength = UNUSED;
      lines = UNUSED;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];

      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentID: "+docID+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Score:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  score = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Score: "+sprintf("%d",score)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_BestMatch:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  bestMatch = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_BestMatch: "+sprintf("%d",bestMatch)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_DocumentLength:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docLength = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentLength: "+sprintf("%d",docLength)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Lines:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  lines = readBinaryInteger(val,buf1);
	  buf1 = buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Lines: "+sprintf("%d",lines)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;

	case DT_TYPE_BLOCK:
	  int size;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_TYPE_BLOCK: \n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

	  buf1 = skipCompressedInteger(buf1);
	  size = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);

	  while (size > 0) {
	    val = readCompressedInteger(buf1);
	    size -= sizeCompressedInteger(buf1);
	    buf1 = skipCompressedInteger(buf1);
	    types  += buf1[0..val];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	    perror("WAIS: got DT_TYPE_BLOCK, type: "+buf1[0..val]+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	    buf1=buf1[val..1000000];
	    size -= val;
	  }
	  break;
	case DT_Source:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  source = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Source: "+source+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Date:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  date = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Date: "+date+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Headline:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  headline = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Headline: "+headline+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
        case DT_OriginCity:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  originCity = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_OriginCity: "+originCity+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_StockCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  stockCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_StockCodes: "+stockCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_CompanyCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  companyCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_CompanyCodes: "+companyCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_IndustryCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  industryCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_IndustryCodes: "+industryCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default 3 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: end DT_DocumentLongHeaderGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      longHeaders += ({ (["versionNumber" : versionNumber,
			  "score" : score,
			  "bestMatch" : bestMatch,
			  "docLength" : docLength,
			  "lines" : lines,
			  "docID" : docID,
			  "types" : types,
			  "source" : source,
			  "date" : date,
			  "headline" : headline,
			  "originCity" : originCity,
			  "stockCodes" : stockCodes,
			  "companyCodes" : companyCodes,
			  "industryCodes" : industryCodes ]) });      
      break;
    case DT_DocumentTextGroup:
      int versionNumber;
      string docID, documentText, buf1;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
      perror("WAIS: got DT_DocumentTextGroup ("+debug_print_string(buf1)+")\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
	  perror("WAIS: got DT_DocumentID: "+debug_print_string(docID)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_DocumentText:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  documentText = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentText: "+documentText+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default 4 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }

      text += ({ (["docID" : docID,
		   "versionNumber" : versionNumber,
		   "documentText" : documentText ]) });
      break;
    case DT_DocumentHeadlineGroup:
      int versionNumber;
      string docID,source,date,headline,originCity,buf1;

      /* readWAISDocumentHeader */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DocumentHeadlineGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      versionNumber = UNUSED;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];

      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentID: "+docID+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Source:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  source = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Source: "+source+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Date:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  date = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Date: "+date+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_Headline:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  headline = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_Headline: "+headline+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
        case DT_OriginCity:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  originCity = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_OriginCity: "+originCity+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default 3 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: end DT_DocumentHeadlineGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      headlines += ({ (["versionNumber" : versionNumber,
			"docID" : docID,
			"source" : source,
			"date" : date,
			"headline" : headline,
			"originCity" : originCity ]) });      
      break;
    case DT_DocumentCodeGroup:
      int versionNumber;
      string docID,stockCodes,companyCodes,industryCodes,buf1;

      /* readWAISDocumentHeader */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_DocumentCodeGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      versionNumber = UNUSED;

      /* readUserInfoHeader */

      buf = skipCompressedInteger(buf);
      size = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      buf1=buf[0..size-1];
      buf=buf[size..1000000];

      while (strlen(buf1)>0) {
	switch (readCompressedInteger(buf1)) {
	case DT_DocumentID:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  docID = buf1[0..val-1];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_DocumentID: "+docID+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_VersionNumber:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  versionNumber = readBinaryInteger(val,buf1);
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_VersionNumber: "+sprintf("%d",versionNumber)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_StockCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  stockCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_StockCodes: "+stockCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_CompanyCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  companyCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_CompanyCodes: "+companyCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	case DT_IndustryCodes:
	  buf1 = skipCompressedInteger(buf1);
	  val = readCompressedInteger(buf1);
	  buf1 = skipCompressedInteger(buf1);
	  industryCodes = buf1[0..val];
	  buf1=buf1[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got DT_IndustryCodes: "+industryCodes+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  break;
	default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
	  perror("WAIS: got default 3 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
	  return 0;
	  break;
	}
      }
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: end DT_DocumentCodesGroup\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      codes += ({ (["versionNumber" : versionNumber,
		    "docID" : docID,
		    "stockCodes" : stockCodes,
		    "companyCodes" : companyCodes,
		    "industryCodes" : industryCodes ]) });      
      break;
    default:
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got default 4 (ARRRGGGH)\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    }
  }

  return (["seedWordsUsed" : seedWordsUsed,
	   "DocHeaders" : docHeaders,
	   "ShortHeaders" : shortHeaders,
	   "LongHeaders" : longHeaders,
	   "Text" : text,
	   "Headlines" : headlines,
	   "Codes" : codes,
	   "Diagnostics" : diags ]);
}



mapping readSearchResponseAPDU(string buf)
{
  int size,pduType,val;
  int result,count,recordsReturned,nextPos;
  int resultStatus,presentStatus;
  string refID,resto;
  mapping userInfo;

  /* read required part */

  size = readBinaryInteger(HEADER_LEN,buf); 
  buf=buf[HEADER_LEN..1000000];

  resto=buf[size..1000000];
  buf=buf[0..size-1];

  pduType = readBinaryInteger(1,buf);
  buf=buf[1..1000000];

  result = readBinaryInteger(1,buf);
  buf=buf[1..1000000];

  count = readBinaryInteger(3,buf);
  buf=buf[3..1000000];

  recordsReturned = readBinaryInteger(3,buf);
  buf=buf[3..1000000];

  nextPos = readBinaryInteger(3,buf);
  buf=buf[3..1000000];

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror(sprintf("WAIS: Got response %d,%d,%d,%d,%d,%d.\n",size,pduType,
		 result,count,recordsReturned,nextPos));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  resultStatus = presentStatus = UNUSED;
  refID = "";

  /* read optional part */
  
  while (strlen(buf)>0) {
    switch (readCompressedInteger(buf)) {
    case DT_ResultSetStatus:
      buf = skipCompressedInteger(buf);
      val = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      resultStatus = readBinaryInteger(val,buf);
      buf=buf[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_ResultSetStatus: "+sprintf("%d",resultStatus)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    case DT_PresentStatus:
      buf = skipCompressedInteger(buf);
      val = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      presentStatus = readBinaryInteger(val,buf);
      buf=buf[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_PresentStatus: "+sprintf("%d",presentStatus)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    case DT_ReferenceID:
      buf = skipCompressedInteger(buf);
      val = readCompressedInteger(buf);
      buf = skipCompressedInteger(buf);
      refID = buf[0..val];
      buf=buf[val..1000000];
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got DT_ReferenceID: "+refID+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      break;
    default:
      return 0;
      break;
    }
  }
  
  userInfo = readSearchResponseInfo(resto);

  if(!userInfo)
    return 0;


  /* construct the search object */

  return (["PDUType" : searchResponseAPDU,
	   "SearchStatus" : result,
	   "ResultCount" : count,
	   "NumberOfRecordsReturned" : recordsReturned,
	   "NextResultSetPosition" : nextPos,
	   "ResultSetStatus" : resultStatus,
	   "PresentStatus" : presentStatus,
	   "ReferenceID" : refID,
	   "DatabaseDiagnosticRecords" : userInfo ]);
}



string make_error_page(string error)
{
  return "WAIS Proxy error accessing wide area information system.\n"+error+"\n";
}

void done_fetch_data(array in)
{
  int i,bin;
  mapping query_resp,searchres;
  object to;
  string docname;

  to=in[3];
  destruct(in[4]);
  docname=in[5];
  bin=in[6];

  if(!objectp(to))
    return;

  if(in[1]<2) {
    destruct(to);
    return;
  }

  if(in[2]==0) {
    /* null record returned */

    destruct(to);
    return;
  }

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("WAIS: Got all fetch data ("+
	 debug_print_string(in[0][HEADER_LENGTH..1000000])+").\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  /* Parse the result which came back into memory. */
  query_resp=readSearchResponseAPDU(in[0][HEADER_LENGTH..1000000]);
  searchres = query_resp->DatabaseDiagnosticRecords;

  if (sizeof(searchres->Text)==0) {
    if (sizeof(searchres->Diagnostics)>0 &&
	strlen(searchres->Diagnostics[0]->ADDINFO)>0) {
      write_to_client_and_cache(to, "HTTP/1.0 200 Yo! Wais data comming"
				" soon to a screen near you\n"
				"Content-Type: text/html\n\n"+
				make_error_page(searchres->Diagnostics[0]->
						ADDINFO),0);
    } else {
      write_to_client_and_cache(to, "HTTP/1.0 200 Yo! Wais data comming"
				" soon to a screen near you\n"
				"Content-Type: text/html\n\n"+
				make_error_page(""),0);
    }
  } else {
    if(!bin && (searchres->Text[0]->documentText[0..5]=="<html>" ||
		searchres->Text[0]->documentText[0..5]=="<HTML>"))
      in[7]="text/html";

    if(docname && strlen(docname)>0)
      write_to_client_and_cache(to, "HTTP/1.0 200 Yo! Wais data comming"
				" soon to a screen near you\n"
				"Content-Type: "+in[7]+"\n\n"+
				output_text_record(searchres->Text[0],
						   bin),docname);
    else
      write_to_client_and_cache(to, "HTTP/1.0 200 Yo! Wais data comming"
				" soon to a screen near you\n"
				"Content-Type: "+in[7]+"\n\n"+
				output_text_record(searchres->Text[0],
						   bin),0);
  }
  destruct(to);
  --roxen->num_connections;
}


void got_fetch_data(array i, string s)
{
  int q,t;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: Got some fetch data.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  i[0] += s;

  switch(i[1]) {
  case 0:
    /* waiting for first '0' char */
    if((q=search(i[0],"0"))==-1)
      return;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Got first 0.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
    
    if(q>0)
      i[0]=i[0][q..1000000];
    i[1]=1;
  case 1:
    /* waiting to receive a complete header */

    if(sizeof(i[0])<HEADER_LENGTH)
      return;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Got header ("+i[0][0..24]+", len is "+i[0][0..9]+").\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    for(t=0;i[0][t]=='0';t++)
      ;

    if(sscanf(i[0][t..10],"%dz",q)!=1) {
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: message header error.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      destruct(i[3]);
      destruct(i[4]);
      return;
    }

    i[2]=q;
    i[1]=2;

  case 2:
    /* waiting to receive all the datas */

    if(sizeof(i[0])>=i[2]+HEADER_LENGTH) {

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror(sprintf("WAIS: got all fetch datas (%d on %d).\n",sizeof(i[0]),
	i[2]));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      i[1]=3;
      done_fetch_data(i);
    }
  }
}



void done_search_data(array in)
{
  int i,bin;
  mapping query_resp;
  object to;
  string database,key;

  to=in[3];
  destruct(in[4]);
  database=in[5];
  key=in[6];

  if(!objectp(to))
    return;

  if(in[1]<2) {
    destruct(to);
    return;
  }

  if(in[2]==0) {
    /* null record returned */

    destruct(to);
    return;
  }

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
  perror("WAIS: Got all search data ("+
	 debug_print_string(in[0][HEADER_LENGTH..1000000])+").\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  /* Parse the result which came back into memory. */
  query_resp=readSearchResponseAPDU(in[0][HEADER_LENGTH..1000000]);

  write_to_client_and_cache(to, display_search_response(query_resp,database,
							key)+"</BODY></HTML>",
			    0);
  destruct(to);
  --roxen->num_connections;
}


void got_search_data(array i, string s)
{
  int q,t;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: Got some search data.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  i[0] += s;

  switch(i[1]) {
  case 0:
    /* waiting for first '0' char */
    if((q=search(i[0],"0"))==-1)
      return;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Got first 0.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
    
    if(q>0)
      i[0]=i[0][q..1000000];
    i[1]=1;
  case 1:
    /* waiting to receive a complete header */

    if(sizeof(i[0])<HEADER_LENGTH)
      return;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Got header ("+i[0][0..24]+", len is "+i[0][0..9]+").\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    for(t=0;i[0][t]=='0';t++)
      ;

    if(sscanf(i[0][t..10],"%dz",q)!=1) {
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: message header error.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      destruct(i[3]);
      destruct(i[4]);
      return;
    }

    i[2]=q;
    i[1]=2;

  case 2:
    /* waiting to receive all the datas */

    if(strlen(i[0])>=i[2]+HEADER_LENGTH) {

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
      perror("WAIS: got all search datas.\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
      i[1]=3;
      done_search_data(i);
    }
  }
}




void connected(object ok, string file, object send_to, string key)
{
  string key,database,doctype,docname,basetitle;
  int doclen,i;
  string reqmsg,header;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: Connected\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  if(!send_to)
  {
    destruct(ok);
    return;
  }

  if(!ok)
  {
    send_to->end(CONNECTION_REFUSED);
    return;
  }

  key=send_to->query;

  if(key && strlen(key)==0)
    key=0;


  if(!key) {
    if((i=search(file,"/"))!=-1) {
      database=file[0..i-1];
      file=file[i+1..10000];
    }

    if((i=search(file,"/"))!=-1) {
      doctype=file[0..i-1];
      file=file[i+1..10000];

      if(sscanf(file, "%d/", doclen)==1) {
	file=file[search(file,"/")+1..10000];
	docname=file;
      }
    } else if(!key)
      key="";
  } else {
    if((i=search(file,"?"))!=-1) {
      database=file[0..i-1];
      file=file[i+1..10000];
    }
    else if((i=search(file,"/"))!=-1) {
      database=file[0..i-1];
      file=file[i+1..10000];
    }
    else
      database=file;
  }

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: request is:\nkey "+key+"\ndatabase "+database+"\ndoctype "+
	 doctype+"\ndoclength "+sprintf("%d",doclen)+"\ndocname "+docname+
	 "\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  

  basetitle=database;

/*	If keyword search is performed but there are no keywords,
 *	the user has followed a link to the index itself. It would be
 *	appropriate at this point to send him the .SRC file - how?
 */

  if(key && strlen(key)==0) {		/* I N D E X */
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Index\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    send_to->my_fd->write("HTTP/1.0 200 Yo! Wais data comming soon to a "
			  "screen near you\nContent-Type: text/html\n\n"
			  "<HTML><TITLE>"+basetitle+" Index</TITLE>"
			  "<BODY><H1>WAIS Index: "+basetitle+"</H1>"
			  "<ISINDEX PROMPT=\"Wais search:  \">");
    destruct(ok);
    destruct(send_to);
  } else if (key) {					/* S E A R C H */

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Search\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    replace(key,({"+"}),({" "}));

    if(!(reqmsg = generate_search_apdu(key,database,1000))) {
      send_to->end(CONNECTION_REFUSED);
      destruct(ok);
      destruct(send_to);
      return;
    }

    header  = sprintf("%010d",strlen(reqmsg));  
    header += "z";
    header += HEADER_VERSION;
    header += "wais      ";
    header += NO_COMPRESSION;
    header += NO_ENCODING;
    header += "0";
    header += reqmsg;
    
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
    perror("about to send message ("+debug_print_string(header)+")\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
    
    /* Write out message. Read back header. */
    
    ok->write(header);
    ok->set_nonblocking(got_search_data, lambda(){},done_search_data);
    ok->set_id(({ "", 0, 0, send_to, ok,database, key }));

    send_to->my_fd->write("HTTP/1.0 200 Yo! Wais data comming soon to a "
			  "screen near you\nContent-Type: text/html\n\n"
			  "<HTML><TITLE>"+key+" in "+basetitle+"</TITLE>"
			  "<BODY><H1>WAIS Search of \""+key+" in "+basetitle+
			  "</H1><ISINDEX PROMPT=\"Wais search:  \">");
    return;
  } else {			/* D O C U M E N T    F E T C H */
    string format;
    int bin;
    string docid;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror("WAIS: Fetch... Retrieve document `"+docname+
	   "'\n............ type `"+doctype+
	   sprintf("' length %d\n", doclen)+"\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    switch(doctype) {
    case "WSRC":
      format="application/x-wais-source";
      bin=0;
      break;
    case "TEXT":
      bin=0;
      format="text/plain";
      break;
    case "HTML":
      bin=0;
      format="text/html";
      break;
    case "GIF":
      bin=1;
      format="image/gif";
      break;
    default:
      bin=1;
      format="application/octet-stream";
      break;
    }

    /* Decode hex or litteral format for document ID */
    docid=WAIS_from_WWW(docname);

    if(!(reqmsg = generate_retrieval_apdu(docid, doctype,database))) {
      send_to->end(CONNECTION_REFUSED);
      destruct(ok);
      destruct(send_to);
      return;
    }

    header  = sprintf("%010d",strlen(reqmsg));  
    header += "z";
    header += HEADER_VERSION;
    header += "wais      ";
    header += NO_COMPRESSION;
    header += NO_ENCODING;
    header += "0";
    header += reqmsg;
    
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG_2
    perror("about to send message ("+debug_print_string(header)+")\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
    
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
    perror(sprintf("requesting document type %s, binary %d)\n",format,bin));
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

    /* Write out message. Read back header. */
    
    ok->write(header);
    ok->set_nonblocking(got_fetch_data, lambda(){},done_fetch_data);
    ok->set_id(({ "", 0, 0, send_to, ok,docname,bin,format }));
    return;
  }
}





mapping find_file(string fi, object id)
{
  mixed tmp;
  string h, f;
  int p;
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: find_file("+fi+")\n");
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif

  sscanf(fi, "%[^/]/%s", h, f);
  if(!f)
    f="";

  sscanf(h, "%s:%d", h, p);
  if(!p)
    p=210;

string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#ifdef WAIS_DEBUG
  perror("WAIS: host = "+h+"\nfile = "+f+"\nport = "+p+"\n");  
string cvs_version = "$Id: wais.pike,v 1.3 1996/11/27 13:48:12 per Exp $";
#endif
  
  if(tmp = proxy_auth_needed(id))
    return tmp;

  if(id->pragma["no-cache"] || id->method != "GET") {
    async_connect(h, p, connected, f, id, h+":"+p+"/"+f);
  } else {
    async_cache_connect(h, p, "wais", h+":"+p+"/"+f,
			connected, f, id, h+":"+p+"/"+f);
  }
  id->do_not_disconnect = 1;  
  return http_pipe_in_progress();
}

string info()
{ 
  return ("This is a caching wais gateway, useful for firewall sites and "
	  "for everyone who wants to aquire better 'surfing speed'.");
}
