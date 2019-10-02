#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_PROVIDER;

constant module_name = "Translit";
constant module_doc = "Transliteration is the method of representing letters or "
  "words of one alphabet in the characters of another alphabet or script. When "
  "transliteration applied to Russian letters to represent them in Latin characters "
  "is called Translit.";

//#define TRANSLIT_DEBUG
#ifdef TRANSLIT_DEBUG
void TRANSLIT_DEBUG_MSG(mixed ... args) {
  report_debug("TRANSLIT_DEBUG: " + args[0], @args[1..]);
}
#else
#define TRANSLIT_DEBUG_MSG(args...) 0
#endif
#define TRANSLIT_ERROR(X, Y...) report_error ("TRANSLIT_ERROR: " + X ,Y)

public multiset(string) query_provides() {
  return (< "translit" >);
}

// -- Basic Russian alphabet
// 0410         А       CYRILLIC CAPITAL LETTER A
// 0430         а       CYRILLIC SMALL LETTER A
// 0411         Б       CYRILLIC CAPITAL LETTER BE
// 0431         б       CYRILLIC SMALL LETTER BE
// 0412         В       CYRILLIC CAPITAL LETTER VE
// 0432         в       CYRILLIC SMALL LETTER VE
// 0413         Г       CYRILLIC CAPITAL LETTER GHE
// 0433         г       CYRILLIC SMALL LETTER GHE
// 0414         Д       CYRILLIC CAPITAL LETTER DE
// 0434         д       CYRILLIC SMALL LETTER DE
// 0415         Е       CYRILLIC CAPITAL LETTER IE
// 0435         е       CYRILLIC SMALL LETTER IE
// 0416         Ж       CYRILLIC CAPITAL LETTER ZHE
// 0436         ж       CYRILLIC SMALL LETTER ZHE
// 0417         З       CYRILLIC CAPITAL LETTER ZE
// 0437         з       CYRILLIC SMALL LETTER ZE
// 0418         И       CYRILLIC CAPITAL LETTER I
// 0438         и       CYRILLIC SMALL LETTER I
// 0419         Й       CYRILLIC CAPITAL LETTER SHORT I
// 0439         й       CYRILLIC SMALL LETTER SHORT I
// 041A         К       CYRILLIC CAPITAL LETTER KA
// 043A         к       CYRILLIC SMALL LETTER KA
// 041B         Л       CYRILLIC CAPITAL LETTER EL
// 043B         л       CYRILLIC SMALL LETTER EL
// 041C         М       CYRILLIC CAPITAL LETTER EM
// 043C         м       CYRILLIC SMALL LETTER EM
// 041D         Н       CYRILLIC CAPITAL LETTER EN
// 043D         н       CYRILLIC SMALL LETTER EN
// 041E         О       CYRILLIC CAPITAL LETTER O
// 043E         о       CYRILLIC SMALL LETTER O
// 041F         П       CYRILLIC CAPITAL LETTER PE
// 043F         п       CYRILLIC SMALL LETTER PE
// 0420         Р       CYRILLIC CAPITAL LETTER ER
// 0440         р       CYRILLIC SMALL LETTER ER
// 0421         С       CYRILLIC CAPITAL LETTER ES
// 0441         с       CYRILLIC SMALL LETTER ES
// 0422         Т       CYRILLIC CAPITAL LETTER TE
// 0442         т       CYRILLIC SMALL LETTER TE
// 0423         У       CYRILLIC CAPITAL LETTER U
// 0443         у       CYRILLIC SMALL LETTER U
// 0424         Ф       CYRILLIC CAPITAL LETTER EF
// 0444         ф       CYRILLIC SMALL LETTER EF
// 0425         Х       CYRILLIC CAPITAL LETTER HA
// 0445         х       CYRILLIC SMALL LETTER HA
// 0426         Ц       CYRILLIC CAPITAL LETTER TSE
// 0446         ц       CYRILLIC SMALL LETTER TSE
// 0427         Ч       CYRILLIC CAPITAL LETTER CHE
// 0447         ч       CYRILLIC SMALL LETTER CHE
// 0428         Ш       CYRILLIC CAPITAL LETTER SHA
// 0448         ш       CYRILLIC SMALL LETTER SHA
// 0429         Щ       CYRILLIC CAPITAL LETTER SHCHA
// 0449         щ       CYRILLIC SMALL LETTER SHCHA
// 042A         Ъ       CYRILLIC CAPITAL LETTER HARD SIGN
// 044A         ъ       CYRILLIC SMALL LETTER HARD SIGN
// 042B         Ы       CYRILLIC CAPITAL LETTER YERU
// 044B         ы       CYRILLIC SMALL LETTER YERU
// 042C         Ь       CYRILLIC CAPITAL LETTER SOFT SIGN
// 044C         ь       CYRILLIC SMALL LETTER SOFT SIGN
// 042D         Э       CYRILLIC CAPITAL LETTER E
// 044D         э       CYRILLIC SMALL LETTER E
// 042E         Ю       CYRILLIC CAPITAL LETTER YU
// 044E         ю       CYRILLIC SMALL LETTER YU
// 042F         Я       CYRILLIC CAPITAL LETTER YA
// 044F         я       CYRILLIC SMALL LETTER YA
// -- Cyrillic extensions
// 0401         Ё       CYRILLIC CAPITAL LETTER IO
// 0451         ё       CYRILLIC SMALL LETTER IO
// -- Other
// 2116         №       'NUMERO SIGN'
// 00AB         «       'LEFT-POINTING DOUBLE ANGLE QUOTATION MARK'
// 00BB         »       'RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK'
// -- Basic Latin (selective)
// 0041         A       Latin Capital letter A
// 0061         a       Latin Small Letter A
// 0042         B       Latin Capital letter B
// 0062         b       Latin Small Letter B
// 0043         C       Latin Capital letter C
// 0063         c       Latin Small Letter C
// 0044         D       Latin Capital letter D
// 0064         d       Latin Small Letter D
// 0045         E       Latin Capital letter E
// 0065         e       Latin Small Letter E
// 0046         F       Latin Capital letter F
// 0066         f       Latin Small Letter F
// 0047         G       Latin Capital letter G
// 0067         g       Latin Small Letter G
// 0048         H       Latin Capital letter H
// 0068         h       Latin Small Letter H
// 0049         I       Latin Capital letter I
// 0069         i       Latin Small Letter I
// 004A         J       Latin Capital letter J
// 006A         j       Latin Small Letter J
// 004B         K       Latin Capital letter K
// 006B         k       Latin Small Letter K
// 004C         L       Latin Capital letter L
// 006C         l       Latin Small Letter L
// 004D         M       Latin Capital letter M
// 006D         m       Latin Small Letter M
// 004E         N       Latin Capital letter N
// 006E         n       Latin Small Letter N
// 004F         O       Latin Capital letter O
// 006F         o       Latin Small Letter O
// 0050         P       Latin Capital letter P
// 0070         p       Latin Small Letter P
// 0051         Q       Latin Capital letter Q
// 0071         q       Latin Small Letter Q
// 0052         R       Latin Capital letter R
// 0072         r       Latin Small Letter R
// 0053         S       Latin Capital letter S
// 0073         s       Latin Small Letter S
// 0054         T       Latin Capital letter T
// 0074         t       Latin Small Letter T
// 0055         U       Latin Capital letter U
// 0075         u       Latin Small Letter U
// 0056         V       Latin Capital letter V
// 0076         v       Latin Small Letter V
// 0057         W       Latin Capital letter W
// 0077         w       Latin Small Letter W
// 0058         X       Latin Capital letter X
// 0078         x       Latin Small Letter X
// 0059         Y       Latin Capital letter Y
// 0079         y       Latin Small Letter Y
// 005A         Z       Latin Capital letter Z
// 007A         z       Latin Small Letter Z
// 0023         #       Number sign
// 0022         "       Quotation mark
// 0027         '       Apostrophe
// -- Tranliteration table using Universal
// 0410         А       0041         A
// 0430         а       0061         a
// 0411         Б       0042         B
// 0431         б       0062         b
// 0412         В       0056         V
// 0432         в       0076         v
// 0413         Г       0047         G
// 0433         г       0067         g
// 0414         Д       0044         D
// 0434         д       0064         d
// 0415         Е       0045         E
// 0435         е       0065         e
// 0401         Ё       004A         J  004F         O
// 0451         ё       006A         j  006F         o
// 0416         Ж       005A         Z  0048         H
// 0436         ж       007A         z  0068         h
// 0417         З       005A         Z
// 0437         з       007A         z
// 0418         И       0049         I
// 0438         и       0069         i
// 0419         Й       004A         J
// 0439         й       006A         j
// 041A         К       004B         K
// 043A         к       006B         k
// 041B         Л       004C         L
// 043B         л       006C         l
// 041C         М       004D         M
// 043C         м       006D         m
// 041D         Н       004E         N
// 043D         н       006E         n
// 041E         О       004F         O
// 043E         о       006F         o
// 041F         П       0050         P
// 043F         п       0070         p
// 0420         Р       0052         R
// 0440         р       0072         r
// 0421         С       0053         S
// 0441         с       0073         s
// 0422         Т       0054         T
// 0442         т       0074         t
// 0423         У       0055         U
// 0443         у       0075         u
// 0424         Ф       0046         F
// 0444         ф       0066         f
// 0425         Х       0048         H
// 0445         х       0068         h
// 0426         Ц       0043         C
// 0446         ц       0063         c
// 0427         Ч       0043         C  0048         H
// 0447         ч       0063         c  0068         h
// 0428         Ш       0053         S  0048         H
// 0448         ш       0073         s  0068         h
// 0429         Щ       0053         S  0048         H  0048         H
// 0449         щ       0073         s  0068         h  0068         h
// 042A         Ъ       0022         "
// 044A         ъ       0022         "
// 042B         Ы       0059         Y
// 044B         ы       0079         y
// 042C         Ь       0027         '
// 044C         ь       0027         '
// 042D         Э       004A         J  0045         E
// 044D         э       006A         j  0065         e
// 042E         Ю       004A         J  0055         U
// 044E         ю       006A         j  0075         u
// 042F         Я       004A         J  0041         A
// 044F         я       006A         j  0061         a
// 2116         №       0023         #
// 00AB         «
// 00BB         »
// -- Transliteration table modifications as per requested from RU
// 042D         Э       0045         E
// 044D         э       0065         e

constant cyrillic =
  ({"410", "430", "411", "431", "412", "432", "413", "433", "414", "434",
    "415", "435", "401", "451", "416", "436", "417", "437", "418", "438",
    "419", "439", "41A", "43A", "41B", "43B", "41C", "43C", "41D", "43D",
    "41E", "43E", "41F", "43F", "420", "440", "421", "441", "422", "442",
    "423", "443", "424", "444", "425", "445", "426", "446", "427", "447",
    "428", "448", "429", "449", "42A", "44A", "42B", "44B", "42C", "44C",
    "42D", "44D", "42E", "44E", "42F", "44F", "2116", "AB", "BB"});

constant latin =
  ({"41", "61", "42", "62", "56", "76", "47", "67", "44", "64",
    "45", "65", "4A4F", "6A6F", "5A48", "7A68", "5A", "7A", "49", "69",
    "4A", "6A", "4B", "6B", "4C", "6C", "4D", "6D", "4E", "6E",
    "4F", "6F", "50", "70", "52", "72", "53", "73", "54", "74",
    "55", "75", "46", "66", "48", "68", "43", "63", "4348", "6368",
    "5348", "7368", "534848", "736868", "22", "22", "59", "79", "27", "27",
    "45", "65", "4A55", "6A75", "4A41", "6A61","23", "", ""});

public string translit(string text) {
  string translit_text = "";

  foreach (text / 1, string char) {
    if (char == "") continue;
    string hex_char;
    mixed err = catch {
        hex_char = sprintf ("%X",char[0]);
        hex_char = replace (hex_char, cyrillic, latin);
        translit_text += String.hex2string (hex_char);
      };

    if (err) {
      TRANSLIT_ERROR ("translit failed - char:%O hex_char:%O\n%O\n",
                      char, hex_char, describe_backtrace (err));
      continue;
    }
  }

  TRANSLIT_DEBUG_MSG ("translit: %O=>%O\n", text, translit_text);
  return translit_text;
}
