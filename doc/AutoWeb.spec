AutoWeb - utkast till specförslag (behöver lite mer detaljer)

Såhär kan det se ut:

  +----------------------------------------------------------------+
  |RoXen                               Företag: Linux Allehanda AB |         
  |                                                                |
  | /Mallverktyg\   /HTML-editor\  /Statistik\ /Hjälp\             |
  |                                                                |
  |       [Vald vy]                                                |
  /                                                                /
        ...                                                        
  /                                                                /
  |                                                                |
  +----------------------------------------------------------------+


De olika vyerna:

   Mallverktyg:
   ------------

   · Koncept: man väljer en huvudtemplate, samt en navigationtemplate.
     Man kan sedan ändra ett antal parametrar (färger, typsnitt, bilder etc.)
   · I templaten märks parametrarna upp med "$$parameternamn$$" eller dylikt.
   · Till templaten hör en templatebeskrivningsfil:
       <variable name="bgcolor" type="color" title="Background color">
          [hjälptext]
       </variable>
       <variable name="fgcolor" type="color" title="Foreground color">
          [hjälptext]
       </variable>
       ....

       Med hjälp av denna fil produceras ett antal wizards, antingen genom
       att skriva en pike-fil till disk eller dynamiskt leka med funktionspekare
       på något jobbigt sätt i en wizard.
   · Man vill nog även kunna ändra varje parameter för sig, utan att stega
     igenom den stora wizarden. Till exempel lista varje parameter, med en länk
     till en ensides-wizard.



   HTML-editor:
   ------------

   · Väldigt lik filväljaren i SiteBuilder (manager/tabs/10:files/page.pike).
     (En fillistning, med ett par knappar under. Zoomar man in på en fil
      dyker ett gäng andra knappar upp, till exempel radera fill/editera fil etc.)
   · Oklart om man ska tillåta underbibliotek...
   · Knappar i filsurfningsläge:
     · Skapa ny fil
     · Ladda upp fil
   · Knappar i inzoomat läge (på fil):
     · Visa
     · Editera
     · Editera metadata
     · Ladda ner filen
     · Ladda upp filen
     · Radera filen
     · Lägg till i menyn/tag bort från menyn
   · Menyeditor (bara för att ändra ordningen på knapparna)


   Statistik:
   ----------
   · Man får se en färdigkomponerad rapport, med några vackra diagram etc.
     

   Hjälp:
   ------

   En liten hjälpsida kan kanske behövas...