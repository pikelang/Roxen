#!pike
/*


	csvimport.pike, version 1.0
	(c) UniBASE Ltd., hop@unibase.cz


	Command:
	--------
	csvimport.pike <hostname> <dn> < pass | - > <filename.cvs> <reftab.tbl>

	where
		hostname	hostname of ldap server
		dn		DN of authenticated user
		pass		password of auth. user, or '-' for interactive
				insertion
		filename.csv	datafile CSV
		reftab.tbl	filename of refference table 

	History:
	--------
	v1.0	1998-11-20	hop:
		created


*/


#define DEBUG(msg)	write("DEBUG: " + msg)

object subfile;
string subname;

array(string) read_elems(string elemsline) {

    array(string) rvarr;

	elemsline = replace(elemsline, "\"", "");
	elemsline = replace(elemsline, "\r", "");
	//DEBUG("CSV popiska: " + elemsline + "\n");
	rvarr = elemsline / ",";
	return(rvarr);
}

string write_nonproc(string label, string line) {
// Zapise nezpracovany/chybny radek do specialniho souboru

	if(!objectp(subfile)) {
	    subfile=Stdio.FILE();
	    subfile->open(subname, "cw");
	}

	subfile->write(line+"\n");
	return("");
}

/* ------------------ MAIN -------------------------- */
int main(int argc, array(string) argv) {

    object dir, en, infile=Stdio.FILE(), tbl=Stdio.FILE();
    string passw = "", strbuf, dn, attrname, label;
    array(string) strarr;
    mapping attrx = ([]), elem = ([]), cmds = ([]);
    int ix, linelen, cnt=1, actlen;

	if(argc < 6) {
	    write("Nedostatecny pocet parametru!\n");
	    write("\nPouziti:\n");
	    write("    csvimport <hostname> <dn> <pasword> <datafile.csv> <reftab.tbl>\n");
	    exit(1);
	}
	// existuji oba soubory?
	if (!file_stat(argv[4])) {
	    write(sprintf("Soubor dat [%s] neexistuje!\n", argv[4]));
	    exit(2);
	}
	subname=argv[4] + ".errdata";
	if (!file_stat(argv[5])) {
	    write(sprintf("Soubor referenci [%s] neexistuje!\n", argv[5]));
	    exit(2);
	}
	// je mozne se pripojit k serveru?
	passw = argv[3];
	if (passw == "-") {
	    write("Zadejte heslo:");
	    //read(passw);
	}
	catch( dir=Protocols.LDAP.client(argv[1]) );
	if (!objectp(dir)) {
	    write(sprintf("Nelze se pripojit k LDAP serveru [%s] !\n", argv[1]));
	    exit(3);
	}
	if(dir->bind(argv[2], passw)) {
	    write(sprintf("Nelze se prihlasit k LDAP serveru [%s] !\n", argv[1]));
	    exit(4);
	}
	// OK. Takze parametry jsou v poradku!

	// Ted nacteme prevodni tabulku, ktera definuje mapovani
	// mezi pojmenovanymi vstupnimi radky a atributy.
	// attrname: csvname1[|csvname2[|...]]
	// ...
	// Radek zacinajici na '@' obsahuje klicova slova a neni soucasti
	// vystupu. Napr. '@req:cn|sn' ukazuje, ze MUSI existovat
	// atributy 'cn a sn', jinak se vystup neprovede!
	DEBUG(" oteviram soubor: " + argv[5] + " ...\n");
	tbl->open(argv[5], "r");
	while(stringp(strbuf = tbl->gets())) {
	    string attrval;

	    //DEBUG("tbl-line: " + strbuf + "\n");
	    if(!sizeof(strbuf))
		continue;
	    if(strbuf[0] == '#')
		continue;
	    if(strbuf[0] == '@') {
		array atmp = strbuf / ":";

		if (sizeof(atmp) > 1) {
		    //cmds += ([(strbuf / ":")[0]:((strbuf / ':')[1]) / "|" ]);
		    cmds += ([ atmp[0][1..] : (atmp[1] / "|") ]);
		}
		continue;
	    }
	    attrname = (strbuf / ":")[0];
	    if(!sizeof(attrname) || (sizeof(strbuf / ":") < 2))
		continue;
	    attrval = (strbuf / ":")[1];
	    attrx[attrname] = attrval / "|";
	} // while
	tbl->close();
	//DEBUG(sprintf("%O\n", attrx));

	// Takze mame prectenu prevodni tabulku.
	// Ted nacteme 1. radek csv souboru a zamenime
	// v tabulce pojmenovane odkazy (napr. $Last Name$)
	// na ciselne odkazy sloupce (tj. napr. $2)
	infile->open(argv[4]);
	label = infile->gets();	// 1. radek = popisky
	strarr = read_elems(label);
	linelen = sizeof(strarr);
	//DEBUG(sprintf("strarr: %O\n", strarr));
	DEBUG("Pocet polozek na radce: " + (string)linelen + "\n");

	//
	foreach(indices(attrx), attrname)  // pro vsechny atributy
	    foreach(attrx[attrname], string tmp)  // pro kazdy prvek atributu
		if(search(tmp, "$")<0)
		    continue;
		else {
		    //DEBUG(sprintf("tmp: %O\n", tmp));
		    for(ix=0; ix<linelen; ix++)  // projede vsechny popisky
			if(search(tmp, "$" + strarr[ix] + "$")>-1) {
			    array(string) tmparr = attrx[attrname];

			    //DEBUG("<" + tmp + "> $" + strarr[ix] + "$ -> " + (string)ix + "\n");
			    attrx -= ([attrname:tmparr]);
			    tmparr -= ({ tmp });
			    tmp = replace (tmp, "$" + strarr[ix] + "$", "$" + (string)ix + "$");
			    tmparr += ({ tmp });
			    //DEBUG(sprintf(" [%s]:\n -> %O\n", attrname, tmparr));
			    attrx += ([attrname:tmparr]);

			}
		} // else
	DEBUG(sprintf("ATTRX: %O\n", attrx));
	DEBUG(sprintf("CMDS: %O\n", cmds));

	// OK. Uz je pripravena prevodni tabulka.
	// Zaciname s importem dat ...
	while(stringp(strbuf = infile->gets())) {
	    strarr = read_elems(strbuf);
	    cnt++;
	    actlen = sizeof(strarr);
	    if(actlen<linelen) {
		write(sprintf("Radek %d obsahuje pouze %d prvku!\n", cnt, sizeof(strarr)));
		//exit(5);
	    }
	    elem = attrx + ([]); // copy_of
	    foreach(indices(elem), attrname)  // pro vsechny atributy
	        foreach(elem[attrname], string tmp)  // pro kazdy prvek atributu
		    if(search(tmp, "$")<0)
		        continue;
		    else {
		        //DEBUG(sprintf("tmp: %O\n", tmp));
		        for(ix=0; ix<linelen; ix++)
			    if(search(tmp, "$" + (string)ix + "$")>-1) {
			        array(string) tmparr = elem[attrname];

			        elem -= ([attrname:tmparr]);
				if(ix < actlen) {
				    // Nahradit jen existujicimi poly
				    // Jinak aspon smazat
				    tmparr -= ({ tmp });
				    tmp = replace (tmp, "$" + (string)ix + "$", strarr[ix]);
				    if(sizeof(tmp))
					tmparr += ({ tmp });
				    if(sizeof(tmparr))
					elem += ([attrname:tmparr]);
				}

			    }
		    } // else
	    if(zero_type(elem["dn"]) || !arrayp(elem->dn) || !stringp(elem->dn[0]) || !sizeof(elem->dn[0])) {
		write("Chybi nebo nespravny attribut 'dn'!\n");
		//exit(6);
		label=write_nonproc(label, strbuf);
		continue;
	    }
	    dn = elem->dn[0];
	    elem -= (["dn":elem->dn]);
	    // ... jeste kontrolu na minimalni sadu atributu
	    if(sizeof(indices(cmds))) {
		int jump = 0;

		if(!zero_type(cmds["req"]) && arrayp(cmds->req) && sizeof(cmds->req))
		    foreach(cmds->req, attrname)
			if(zero_type(elem[attrname])) {
			    write(sprintf("Chybi atribut [%s] !\n", attrname));
			    jump = 1;
			}
		if(jump) {
		    label=write_nonproc(label, strbuf);
		    continue; // ADD se neprovede!
		}
	    }
	    //dir->add(dn, elem);
	    DEBUG(sprintf("ADD: dn=%s\n%O\n", dn, elem));
	    /*if(dir->error_num()) {
		write("Chyba pri vkladani dat!\n");
		exit(9);
	    }*/
	    //DEBUG("dn="+dn+" - added.\n");
	}
	//DEBUG(sprintf("%O\n", elem));
	

	infile->close();
	if(objectp(subfile))
	    subfile->close();

	dir->unbind();
}
