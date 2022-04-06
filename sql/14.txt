-- realizati un pachet cu urmatoarele cerinte
-- cerinta 1 din pachet
/* Sa se afiseze numele, prenumele, ce salariu isi doreste, cat de bine este
 * platit, vechimea la locul de munca curent, la ce firma lucreaza, si ce
 * depozit pazesc toti paznicii care lucreaza in depozite din alte localitati
 * fata de cea in care se afla cel mai vizitat popas de soferii de tir si doar
 * pentru paznicii pentru care a intrat sub paza lor in depozit cel putin un 
 * transport de marfa. Daca un paznic are salariul mai mic decat media salariul
 * din firma in care lucreaza, atunci el isi doreste o marire de salariu cu 200
 * lei, in caz contra doresc o marire de 100 lei. Consideram ca un paznic este 
 * bine platit daca are un salariu mai mare decat 3000 lei inclusiv. Suma de 
 * 3000lei reprezinta media salariilor paznicilor din Romania inidiferent de 
 * locatia pazita(nu intra doar depozitele din gestiunea acestei baze de date).
 * Sa se ordoneze descrescator dupa salariu si in caz de egalitate crescator 
 * dupa nume si prenume. Separati problema principala in cat mai multe generale
 * pentru cazul in care mai pot fi refolosite si in alte cerinte.
 * Tratati exceptiile care pot aparea. Daca in baza de date nu sunt la momentul
 * rularii date suficiente aduceti mici modificari pentru a forta erorile pentru
 * a demonstra ca se executa corect in cazul in care vor aparea. */
-- cerinta 2 din pachet
/* Intr-un subprogram sa se afiseze numele, prenumele, nr. de telefon la care
 * poate fi contact soferul, unde este angajat si data de sosire si plecare
 * pentru oprirea sa la cel mai popular popas. Aceeasi cerinta in aceleasi
 * subprogram pentru toate motelurile */

CREATE OR REPLACE PACKAGE pack_ex14 IS
-- creeaza record pt primul tip
TYPE rec14_info_ang IS RECORD (
    nume_angajat        varchar2(25),
    prenume_angajat     varchar2(25),
    salariu_actual      number(10),
    salariu_dorit       number(10),
    este_platit_bine    varchar2(255), -- fata de restul de angajati din firma
    vechime_angajat     varchar2(255), -- vechime angajat in firma curenta
    nume_firma          varchar2(25),
    id_echipa_paza      number(5)
);

-- informatii despre depozitul in care lucreaza un paznic
TYPE rec14_info_dep IS RECORD(
    id_locatie      number(10),
    judet           varchar2(25),
    localitate      varchar2(25),
    strada          varchar2(25),
    nr              number(5),
    nr_colegi       number(5) -- nr colegi ai paznicului
);

PROCEDURE obtine_cel_mai_vizitat_popas(p_id_popas OUT popas.id_popas%TYPE);
FUNCTION locatie_popas(p_id_popas popas.id_popas%TYPE) RETURN locatie%rowtype;
PROCEDURE info_salariu_din_firma(
    p_id_firma      IN firma.id_firma%TYPE,
    p_tip_angajat   IN angajat.tip_angajat%TYPE,
    p_medie_salariu OUT angajat.salariu%TYPE,
    p_minim_salariu OUT angajat.salariu%TYPE,
    p_maxim_salariu OUT angajat.salariu%TYPE);
FUNCTION f14_paznic_info(
    p_id_angajat angajat.id_angajat%TYPE,
    p_id_firma   firma.id_firma%TYPE) RETURN rec14_info_ang;
FUNCTION f14_depozit_info(p_id_echipa_paza echipa_paza.id_echipa_paza%TYPE)
    RETURN rec14_info_dep;
PROCEDURE p14_info_cer1;
PROCEDURE p14_info_cer2;
END pack_ex14;
/


CREATE OR REPLACE PACKAGE BODY pack_ex14 IS
-- functie pentru a obtine id-ul celui mai vizitat popas la un moment dat
PROCEDURE obtine_cel_mai_vizitat_popas
    (p_id_popas OUT popas.id_popas%TYPE) IS
    exceptie_not_found EXCEPTION;
BEGIN
    SELECT id_popas popas
    INTO p_id_popas
    FROM istoric_popasuri
    GROUP BY id_popas
    HAVING count(id_popas) = (SELECT max(count(id_popas))
                              FROM istoric_popasuri
                              GROUP BY id_popas
                              ); -- pt eroare not found +2;
                              -- forteaza eroare pentru too-many
--                              or count(id_popas) = (SELECT min(count(id_popas))
--                              FROM istoric_popasuri
--                              GROUP BY id_popas
--                              ); 
    -- daca nu a gasit nimic arunca o eroare mai detaliata
    IF SQL%NOTFOUND THEN
        RAISE exceptie_not_found;
    END IF;
EXCEPTION
    WHEN exceptie_not_found THEN
        RAISE_APPLICATION_ERROR(-20141, 'Nu a putut fi gasit cel mai popular popas!');
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20142, 'Au fost gasite mai multe popasuri la fel de vizitate!');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20141, 'Nu a putut fi gasit cel mai popular popas!');
END;

---- pentru a testa exceptiile fortate de la procedura anterioara
--DECLARE
--    p popas.id_popas%TYPE;
--BEGIN
--    obtine_cel_mai_vizitat_popas(p);
--    dbms_output.put_line(p);
--END;

-- functie care primeste id-ul unui popas si intoarce toate datele despre
-- locatia in care se afla
FUNCTION locatie_popas(p_id_popas popas.id_popas%TYPE)
    RETURN locatie%rowtype IS
    rez_loc locatie%rowtype;
    exceptie_not_found EXCEPTION;
BEGIN
    SELECT l.*
    INTO rez_loc
    FROM locatie l JOIN popas p ON (l.id_locatie = p.id_locatie)
    WHERE p.id_popas = p_id_popas;
    
    return rez_loc;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20143, 'Nu a putut fi gasita locatia popasului.');
        RETURN NULL;
END;

---- test exceptie daca se trimite parametru gresit exemplu anterior
--DECLARE
--    l locatie%rowtype;
--BEGIN
--    l := locatie_popas(210);
--EXCEPTION
--    WHEN others THEN
--        DBMS_OUTPUT.PUT_LINE(SQLERRM);
--END;

-- procedura pentru a obtine informatii despre salariile dintr-o firma pentru un
-- anumit tip de angajati (PAZNIC, SOFER)
PROCEDURE info_salariu_din_firma(
    p_id_firma      IN firma.id_firma%TYPE,
    p_tip_angajat   IN angajat.tip_angajat%TYPE,
    p_medie_salariu OUT angajat.salariu%TYPE,
    p_minim_salariu OUT angajat.salariu%TYPE,
    p_maxim_salariu OUT angajat.salariu%TYPE) IS
    exceptie EXCEPTION;
BEGIN
    SELECT round(avg(salariu)), min(salariu), max(salariu)
    INTO p_medie_salariu, p_minim_salariu, p_maxim_salariu
    FROM angajat
    WHERE id_firma = p_id_firma and tip_angajat = p_tip_angajat;
END;

-- obtine informatii despre un paznic
FUNCTION f14_paznic_info(
    p_id_angajat angajat.id_angajat%TYPE,
    p_id_firma   firma.id_firma%TYPE)
    RETURN rec14_info_ang
IS  rezultat rec14_info_ang;
    v_min_salariu       angajat.salariu%TYPE;
    v_medie_salariu     angajat.salariu%TYPE;
    v_max_salariu       angajat.salariu%TYPE;
BEGIN
    -- obtine medie salariu - restul de date le vom ignora
    info_salariu_din_firma(p_id_firma, 'PAZNIC', v_medie_salariu, v_min_salariu, v_max_salariu);
    IF v_medie_salariu is null THEN -- nu au fost obtinute date, arunca exceptie
        RAISE_APPLICATION_ERROR(-20144, 'Nu au putut fi obtinute informatii despre firma');
    END IF;

    -- obtine informatiile si salveaza-le intr-un record
    SELECT a.nume, a.prenume, a.salariu,
        CASE WHEN a.salariu < v_medie_salariu THEN a.salariu + 200
             ELSE a.salariu + 100
        END, -- salariu dorit
        DECODE((a.salariu-3000)-abs(a.salariu-3000)         
         , 0, 'bine platit', 'prost platit'), -- este bine platit fata de restul
        concat(substr(numtodsinterval((sysdate - a.data_angajare), 'DAY'), 8, 3) ||' zile ',
            substr(numtodsinterval((sysdate - a.data_angajare), 'DAY'), 12, 5)), -- vechime la locul de munca in firma
        f.nume, --nume firma,
        a.id_echipa_paza -- din ce echipa de paza face parte 
    INTO rezultat -- salveaza in recordul rezultat
    FROM angajat a JOIN firma f ON (a.id_firma = f.id_firma)
    WHERE a.id_angajat = p_id_angajat 
    ORDER BY a.salariu desc, a.nume, a.prenume;
    
    RETURN rezultat;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20145, 'Nu au fost gasite informatii despre angajat. Angajatul nu exista!');
        RETURN NULL;
END;


-- obtine informatiile despre un depozit la care este repartizata o echipa de
-- paza - informatie despre locatie si nr. de colegi pe care ii are orice paznic
-- i.e. nr. paznici - 1
FUNCTION f14_depozit_info(p_id_echipa_paza echipa_paza.id_echipa_paza%TYPE)
    RETURN rec14_info_dep
IS rezultat rec14_info_dep;
BEGIN
    SELECT l.id_locatie, l.judet, l.localitate, l.strada, l.nr,
        (SELECT count(id_echipa_paza)-1
         FROM angajat 
         WHERE id_echipa_paza = d.id_echipa_paza
         GROUP BY id_echipa_paza)
    INTO rezultat
    FROM depozit d JOIN locatie l ON (d.id_locatie = l.id_locatie)
    WHERE d.id_echipa_paza = p_id_echipa_paza;
    
    RETURN rezultat;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20146, 'Nu au fost gasite informatii despre depozitul in care este repartizata echipa de paza data!');
END;

---- testeaza exceptia de la subprogramul anterior
--DECLARE
--    rezultat rec14_info_dep;
--BEGIN
--    rezultat := f14_depozit_info(2110);
--EXCEPTION
--    WHEN OTHERS THEN
--        DBMS_OUTPUT.PUT_LINE(SQLERRM);
--END;

-- program care le executa
PROCEDURE p14_info_cer1 IS
    -- tabel imbricat pentru informatii despre paznic
    TYPE t_ang_info IS TABLE OF rec14_info_ang;
    ta t_ang_info := t_ang_info();
    
    -- tabel imbricat pentru informatii despre depozitele in care lucreaza paznicii
    TYPE t_dep_paz IS TABLE OF rec14_info_dep;
    td t_dep_paz := t_dep_paz();

    -- record pentru a obtine id-urile angajatilor si firmelor la care lucreaza
    TYPE r_ang_firma IS RECORD (
        id_angajat angajat.id_angajat%TYPE,
        id_firma   firma.id_firma%TYPE
    );
    -- tabel indexat de tip record pentru a se putea face loop cu datele din el
    -- pentru a insera date in tabelele definite anterior folosind functiile
    -- si procedurile create
    TYPE t_ang_firma IS TABLE OF r_ang_firma INDEX BY PLS_INTEGER;
    af t_ang_firma;
    
    -- variabile definite
    v_id_popas_popular      popas.id_popas%TYPE;
    v_locatie_popas_popular locatie%rowtype;
    v_nr_afisari            NUMBER;
    
    -- cursor pentru a popula tabelul indexat
    CURSOR c_ang_firma IS SELECT id_angajat, id_firma
                          FROM angajat
                          WHERE tip_angajat = 'PAZNIC';
BEGIN
    OPEN c_ang_firma; -- deschide cursorul
    FETCH c_ang_firma BULK COLLECT INTO af;
    IF c_ang_firma%rowcount = 0 THEN -- in cazul in care nu s-au obtinut informatii
        RAISE_APPLICATION_ERROR(-20147, 'Nu au putut fi obtinute id-urile paznicilor cu firmele in care lucreaza!');
    END IF;
    CLOSE c_ang_firma; -- inchide cursorul
    
    -- extindem tabelele cu informatii despre angajat si depozite folosind 
    -- marimea tabelului indexat - extindem acum tabelele pentru a nu o face de
    -- fiecare data cand vrem sa inseram ceva
    ta.EXTEND(af.COUNT);
    td.EXTEND(af.COUNT);
    FOR i IN af.FIRST..af.LAST LOOP
     -- TODO pentru a simula un caz de exceptie inlocuieste mai jos cu valori random
        ta(i) := f14_paznic_info(af(i).id_angajat, af(i).id_firma);
        td(i) := f14_depozit_info(ta(i).id_echipa_paza);
    END LOOP;
    
    obtine_cel_mai_vizitat_popas(v_id_popas_popular);
    v_locatie_popas_popular := locatie_popas(v_id_popas_popular);
    
    -- afisare filtrata a informatiilor din tabele
    v_nr_afisari := 0; -- verificam daca au fost afisate informatii
    FOR i in af.FIRST..af.LAST LOOP -- ne folosim tot de tabelul indexat
    -- daca inlocuim cu = putem exemplifica exceptia cand nu se realizeaza afisari
        IF td(i).id_locatie <> v_locatie_popas_popular.id_locatie THEN
        
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Paznicul '||ta(i).nume_angajat||' '||ta(i).prenume_angajat
            ||' are salariul de '||ta(i).salariu_actual||' de lei si ar dori '||
            ta(i).salariu_dorit||' de lei.');
        DBMS_OUTPUT.PUT_LINE('Considerand salariile paznicilor din firma este '
            ||ta(i).este_platit_bine);
        DBMS_OUTPUT.PUT_LINE('A lucrat pentru firma '||ta(i).nume_firma
            ||' timp de '||ta(i).vechime_angajat);
        -- in functie de nr de colegi vom face o afisare speciala
        DBMS_OUTPUT.PUT('In momentul de fata este repartizat ');
        IF td(i).nr_colegi = 0 THEN
            DBMS_OUTPUT.PUT('singur');
        ELSIF td(i).nr_colegi = 1 THEN
            DBMS_OUTPUT.PUT('alatauri de inca un paznic');
        ELSE
            DBMS_OUTPUT.PUT('alaturi de inca '||td(i).nr_colegi||' paznici');
        END IF;
            
        DBMS_OUTPUT.PUT(' intr-un depozit din judetul '||td(i).judet||' localiatea '
            ||td(i).localitate||' pe strada '||td(i).strada||' la nr.'||td(i).nr);
        DBMS_OUTPUT.NEW_LINE();
        v_nr_afisari := v_nr_afisari + 1; -- marcam faptul ca am mai facut o afisare
        END IF;
    END LOOP;
    
    IF v_nr_afisari = 0 THEN -- nu au fost nimic afisat, aruncam o exceptie
        RAISE_APPLICATION_ERROR(-20148, 'Nu au fost gasiti paznici care sa respecte criteriile date');
    END IF;
    
EXCEPTION -- tratarea de exceptii
    -- pentru orice exceptie primita afiseaza mesajul de eroare, deoarece am
    -- creat noi exceptii specializate si detalitate despre ce exceptii ar putea
    -- aparea, in cazul in care alte exceptii neprevazute apar tot va fi afisat
    -- mesajul exceptiei
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

PROCEDURE p14_info_cer2 IS
    TYPE rec_ang_viz IS RECORD (
        data_sosire     istoric_popasuri.data_sosire%TYPE,
        data_plecare    istoric_popasuri.data_plecare%TYPE,
        nume_ang        angajat.nume%TYPE,
        prenume_ang     angajat.prenume%TYPE,
        nr_telefon_ang  angajat.nr_telefon%TYPE,
        nume_firma      firma.nume%TYPE
    );
    TYPE t_ang_viz IS TABLE OF rec_ang_viz;
    t t_ang_viz;

    v_id_popas popas.id_popas%TYPE;
    
    CURSOR c_ist_pop(p_id_popas popas.id_popas%TYPE) IS 
        SELECT ip.data_sosire, ip.data_plecare, a.nume, a.prenume, a.nr_telefon, f.nume
        FROM istoric_popasuri ip JOIN angajat a ON (ip.id_angajat = a.id_angajat)
            JOIN firma f ON (a.id_firma = f.id_firma)
        WHERE ip.id_popas = p_id_popas
        ORDER BY ip.data_sosire desc; -- sorteaza descrescator in functie de cand au venit
BEGIN
    -- pentru cel mai vizitat popas afiseaza informatii despre soferii care au 
    -- venit la el
    obtine_cel_mai_vizitat_popas(v_id_popas);
    
    OPEN c_ist_pop(v_id_popas);
    FETCH c_ist_pop BULK COLLECT INTO t;
    IF c_ist_pop%rowcount = 0 THEN -- pune 1 pentru a testa exceptia
        RAISE_APPLICATION_ERROR(-20149, 'Nu a vizitat niciun sofer motelul cu id-ul '||v_id_popas);
    END IF;
    CLOSE c_ist_pop;
    FOR i IN t.FIRST..t.LAST LOOP
        DBMS_OUTPUT.PUT_LINE('La data de '||t(i).data_sosire||' a venit soferul '
            ||t(i).nume_ang||' '||t(i).prenume_ang||' cu nr. de telefon '||
            t(i).nr_telefon_ang||' angajat la'||t(i).nume_firma||' si a plecat la '
            ||t(i).data_plecare);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------'); 
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------'); 

    DBMS_OUTPUT.NEW_LINE(); -- separator intre cerinte
    -- afiseaza aceleasi informatii pentru toate motelele
    -- ciclu cursor cu subcerere
    FOR p IN (SELECT id_popas FROM popas WHERE tip_popas = 'MOTEL') LOOP
        -- sterge informatiile din tabel pentru a retine alte date
        t.DELETE();    
        -- obtine un istoric al opririlor soferilor la motelul curent
        OPEN c_ist_pop(p.id_popas);
        FETCH c_ist_pop BULK COLLECT INTO t LIMIT 3; -- obtine doar primele 3
        IF c_ist_pop%rowcount = 0 THEN -- pune 1 pentru a testa exceptia
            RAISE_APPLICATION_ERROR(-20149, 'Nu a vizitat niciun sofer motelul cu id-ul '||p.id_popas);
        END IF;
        CLOSE c_ist_pop;
        
        FOR i IN t.FIRST..t.LAST LOOP
            DBMS_OUTPUT.PUT_LINE('La data de '||t(i).data_sosire||' a venit soferul '
                ||t(i).nume_ang||' '||t(i).prenume_ang||' cu nr. de telefon '||
                t(i).nr_telefon_ang||' angajat la'||t(i).nume_firma||' si a plecat la '
                ||t(i).data_plecare);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');     
    END LOOP; 
EXCEPTION -- tratarea de exceptii
    -- pentru orice exceptie primita afiseaza mesajul de eroare, deoarece am
    -- creat noi exceptii specializate si detalitate despre ce exceptii ar putea
    -- aparea, in cazul in care alte exceptii neprevazute apar tot va fi afisat
    -- mesajul exceptiei
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

END;
/

EXECUTE pack_ex14.p14_info_cer1;
EXECUTE pack_ex14.p14_info_cer2;