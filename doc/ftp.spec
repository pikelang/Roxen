Some thoughts in Swedish:

Två protokoll http och ftp som skiljer sig på några punkter:

 - http använder sig av en host-header för att välja kund.
 - ftp har ingen host header utan får lägga information i
   inloggningsnamnet namn@domain eller namn*domain.

För att hantera användarkontroll för båda protokollen skrivs lämpligen
en auth-modul som kontrollerar användarnamn och sätter rätt kund.

Endast upload ska stödjas.
Vissa taggar ska tolkas och specialbehandlas.
 - titel       <title>Welcome</title>
 - keywords ur <meta name="keywords" content="Intruduction">
 - description <meta name="description"
                     content="Intruduction to the UltraViking Company">
 - template ur <template> ... </template>
TODO
  Kolla att metadatan extraheras korrekt.
  Fixa cache-reloadbuggen vid uppload.
  kolla om busiga filnamn strular.