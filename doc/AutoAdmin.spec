AutoAdmin (a.k.a. AutoMain) - specförslag

Såhär kan det se ut:

  +----------------------------------------------------------------+
  |RoXen                               Företag: Linux Allehanda AB |         
  |    VÄLJ KUND    RADERA KUND      NY KUND....                   | 
  |----------------------------------------------------------------+
  | /Kund-config\   /DNS-config\  /Mail-config\ /Extratjänster\    |
  |                                                                |
  |       [Vald vy]                                                |
  /                                                                /
        ...                                                        
  /                                                                /
  |                                                                |
  +----------------------------------------------------------------+


De olika vyerna:

   Kund-config:
   ------------

   · Företagsnamn
   · Faxnummer
   · SMS-nummer
   · användarnamn
   · lösenord


   DNS-config:
   -----------

   · Domän: (typ "linuxallehanda.se")
     (ett CNAME för www.linuxallehanda.se, och MX för linuxallehanda.se
      skapas automagiskt.)
     (Behövs mer valmöjligheter? :))
   
   Mail-config:
   ------------

     Delvy 1:
     --------
     · Lista på användare till det valda företaget
     · knapp för "lägg till användare"
     
     Delvy 2:   (inzoomat på en användare)
     --------
     · Fullständigt namn
       (kan även användas till att få automagiska sven.andersson@linuxallehanda.se)
     · användarnamn
     · lösenord
     · .forward (in i den webbaserade webklienten?)
     · Fax-nummer
     · SMS-nummer
     
   Extratjänster:
   --------------
   · [ ] Intraseek
   · [ ] Logview
   · [ ] Fax
   · [ ] SMS

