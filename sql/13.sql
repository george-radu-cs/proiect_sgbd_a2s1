CREATE OR REPLACE PACKAGE pack_ex13 IS
-- 6
FUNCTION func_obtine_data(p_nume_popas popas.nume%type, 
    p_localitate locatie.localitate%TYPE) RETURN varchar2;

PROCEDURE proc_track_sofer(p_nume_popas popas.nume%type, p_localitate locatie.localitate%TYPE);

-- 7
PROCEDURE tracking_proc;

-- 8
FUNCTION func8_info_sofer(p_nume angajat.nume%TYPE, p_prenume angajat.prenume%TYPE)
    RETURN tab8_ang_info%rowtype;
    
-- 9 
PROCEDURE proc9_afisare_transport(p_nr_inmatriculare camion.nr_inmatriculare%TYPE,
    p_data_plecare varchar2);
END pack_ex13;
/

CREATE OR REPLACE PACKAGE BODY pack_ex13 IS
-- 6
FUNCTION func_obtine_data(
    p_nume_popas popas.nume%type, p_localitate locatie.localitate%TYPE)
RETURN varchar2
    AS v_data_rez varchar2(255);
BEGIN
    SELECT to_char(min(sip.data_sosire), 'dd-mm-yyyy')
    INTO v_data_rez
    FROM locatie sl JOIN popas sp ON (sl.id_locatie = sp.id_locatie)
                    JOIN istoric_popasuri sip ON(sp.id_popas = sip.id_popas)
    WHERE initcap(sp.nume) = p_nume_popas and initcap(sl.localitate) = p_localitate;
    
    return v_data_rez;
END;

PROCEDURE proc_track_sofer(
    p_nume_popas popas.nume%type, p_localitate locatie.localitate%TYPE)
AS
    -- record pentru a retine date despre soferi (folosim tipurile de date din
    -- tabelul de angajati)
    TYPE rec_sofer_info IS RECORD (
        id_angajat     angajat.id_angajat%TYPE,
        nume           angajat.nume%TYPE,
        prenume        angajat.prenume%TYPE,
        salariu        angajat.salariu%TYPE,
        bani_cheltuiti angajat.salariu%TYPE
    );
    
    -- tabel indexat (INTEGER) cu model de date de tipul record rec_sofer_info
    TYPE t_sofer_info IS TABLE OF rec_sofer_info INDEX BY PLS_INTEGER;
    
    -- record pentru tracking al soferului la un popas
    TYPE rec_track_info IS RECORD (
        din_ph  varchar2(255),
        nume_popas popas.nume%TYPE,
        tip_popas popas.tip_popas%TYPE,
        ora_sosire varchar2(255),
        durata varchar2(255),
        locatie_popas varchar2(255)
    );
    -- tabel imbricat cu model de date de tipul record rec_track_info
    TYPE t_track_info IS TABLE OF rec_track_info;
    
    -- tabel indexat in care vom retine soferi in functie de criteriul stabilit
    t_soferi t_sofer_info;
    -- tabel imbricat care va retine date de tracking pt sofer
    t_track  t_track_info;
    -- data primei opriri a unui sofer la Restaurantul Ceptura din Ploiesti
    v_data   varchar2(255);
    -- pentru a prinde exceptiile de orice fel (in principiu pentru exceptiile aplicatiei)
    exceptie EXCEPTION;
    PRAGMA EXCEPTION_INIT(exceptie, -20001);
    
    -- cursor clasic pentru a obtine informatii despre toti soferii
    CURSOR c_obtine_soferi IS
        SELECT id_angajat, nume, prenume, salariu,
            CASE WHEN salariu <=3000 THEN salariu * 0.005
                 WHEN salariu <=4500 THEN salariu * 0.01
                 WHEN salariu > 4500 THEN salariu * 0.015
            END 
        FROM angajat
        WHERE tip_angajat = 'SOFER' -- vrem doar soferii din toti angajatii
        ORDER BY nume, prenume; -- ordoneaza soferii crescator dupa nume si prenume
    
    -- cursor parametrizat pentru a obtine date de tracking despre un sofer dat dupa id-ul de angajat
    CURSOR c_track(cp_id_angajat angajat.id_angajat%TYPE, cp_data varchar2) IS
        SELECT 
			-- decode pentru a verifica nr de inmatriculare al camionului pe care il 
			-- conducea soferul la momentul opririi la popas, primele 2 caractere ne
			-- spun daca a fost inmatriculat in Prahova sau in alta regiune
			DECODE((SELECT upper(substr(sc.nr_inmatriculare, 0, 2))
                       FROM camion sc JOIN istoric_camioane_conduse sic ON(sc.id_camion = sic.id_camion)
                       WHERE sic.id_angajat = cp_id_angajat -- verificam angajatul
							-- verificam sa obtinem camionul pe care il conducea la momentul dat
                            and ip.data_sosire < NVL(sic.data_sfarsit, sysdate)
                            and ip.data_sosire > NVL(sic.data_inceput, sysdate)
            ), 'PH', 'in Prahova', 'din alta regiune') "Verifica camion din Prahova", 
            p.nume "Nume popas", initcap(p.tip_popas) "Tip popas",
            to_char(ip.data_sosire, 'hh24:mi') "Ora sosire",
            substr(numtodsinterval((ip.data_plecare - ip.data_sosire), 'DAY'), 12, 5) "Durata",
            'Jud: ' || NVL(l.judet, '-') || ' Loc: ' || NVL(l.localitate, '-') ||
            ' Str. ' || NVL(l.strada, '-') || ' Nr. ' || NVL(to_char(l.nr), '-') "Locatie popas"
        FROM istoric_popasuri ip JOIN popas p ON(ip.id_popas = p.id_popas)
                                 JOIN locatie l ON(p.id_locatie = l.id_locatie)
		-- pentru angajatul dat ca parametru si orice popas din ziua data
        WHERE ip.id_angajat = cp_id_angajat AND to_char(data_sosire, 'dd-mm-yyyy') = cp_data;
BEGIN
    -- obtinem data ceruta din cerinta - folosim parametrii din procedura 
	-- si ii pasam functiei
    v_data := func_obtine_data(p_nume_popas, p_localitate);
    
    -- daca nu a fost obtinuta o data pentru tracking atunci urmatoarele queries
    -- nu mai au sens
    IF v_data is null THEN
        RAISE_APPLICATION_ERROR(-20001, 'Nu a oprit niciun sofer la locatia data. '
        ||'Daca rezultatul nu este cel asteptat verificati datele de intrare.');
    END IF;
       
    -- obtine toti soferii pentru inceput folosind cursorul clasic
    OPEN c_obtine_soferi; -- deschidem cursorul pentru a obtine date
    FETCH c_obtine_soferi BULK COLLECT INTO t_soferi;
    CLOSE c_obtine_soferi; -- dupa ce am obtinut date nu mai avem nevoie de cursor 
	-- deci il inchidem, analog pentru cel parametrizat de la liniile 137-139
    
    -- din conditia sa nu se ia in considerare ultimii 2 angajati
    -- putem folosi direct COUNT intrucat nu s au realizat modificari in tabloul
    -- indexat momentan deci ultimul element va fi reprezentat de nr COUNT
    -- dupa prima stergerea penultimul element vi fi reprezentat tot de nr COUNT
    -- intrucat al doilea COUNT este diferit de primul COUNT
    -- SECOND_COUNT = FIRST_COUNT - 1;
    t_soferi.DELETE(t_soferi.COUNT);
    t_soferi.DELETE(t_soferi.COUNT);

-- simulam cazul in care nu am obtinut soferii
--    t_soferi.DELETE();
--    IF t_soferi.COUNT() = 0 THEN
--        RAISE_APPLICATION_ERROR(-20002, 'Nu s-au putut obtine soferii');
--    END IF;

    FOR i IN t_soferi.FIRST..t_soferi.LAST LOOP
        IF t_soferi.EXISTS(i) THEN -- daca exista angajatul
        
        -- obtine informatii despre tracking pentru soferul curent din loop
        OPEN c_track(t_soferi(i).id_angajat, v_data);
        FETCH c_track BULK COLLECT INTO t_track;
        CLOSE c_track;
        
        -- afiseaza date despre sofer
        DBMS_OUTPUT.PUT_LINE('Soferul '||t_soferi(i).prenume||' '||t_soferi(i).nume||' are salariul de '
            ||t_soferi(i).salariu||' de lei si cheltuie in medie '||t_soferi(i).bani_cheltuiti||' lei '
            ||'la un popas. Informatii de tracking:');
         
        -- soferul curent nu s a oprit la niciun popas in ziua respectiva
        -- nu vrem sa aruncam o exceptie ci sa afisam un mesaj explicit pentru acest caz special
        IF t_track.COUNT() = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Nu s-a oprit la niciun popas in data de '||v_data);
        ELSE
            FOR j IN t_track.FIRST..t_track.LAST LOOP
                DBMS_OUTPUT.PUT_LINE('S-a oprit cu un camion inmatriculat '||t_track(j).din_ph||' la un '||
                   lower(t_track(j).tip_popas)||' din '||t_track(j).locatie_popas||' la ora '||t_track(j).ora_sosire||' unde a stat '
                   ||'pentru o perioada de '||t_track(j).durata||' ore.');
            END LOOP;
        END IF;
       
        -- separator soferii
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');     
        END IF;
        t_track.DELETE();
    END LOOP;

EXCEPTION
    WHEN exceptie THEN -- prinde toate exceptiile si afiseaza codul si mesajul
        DBMS_OUTPUT.PUT_LINE('Cod exceptie: '||SQLCODE||' ; Mesaj: '||SQLERRM);
END;

-- 7
PROCEDURE tracking_proc AS
    TYPE refcursor IS REF CURSOR;
    -- ciclu cursor care obtine date despre un camion si un cursor pentru transporturile
    -- realizate de el
    CURSOR c_camion IS
        SELECT c.id_camion id_camion, c.marca marca, c.nr_inmatriculare nr_inmatriculare,
            f.nume nume_detinator,
            CURSOR (WITH ang AS -- soferii angajati inainte de 13 sept 2020 care detin cel mult 2 permise auto
                        (SELECT p.id_angajat, a.nume, a.prenume, a.salariu
                         FROM angajat a JOIN permis p ON (a.id_angajat = p.id_angajat)
                         WHERE a.tip_angajat = 'SOFER'
                            and to_char(a.data_angajare, 'dd-mm-yyyy') < '13-9-2020' 
                         GROUP BY p.id_angajat, a.nume, a.prenume, a.salariu
                         HAVING count(p.id_angajat) >= 1  -- care detine cel putin 1 permis  
                    )
                    SELECT a.nume nume_sofer, a.prenume prenume_sofer, a.salariu salariu_sofer,
                        to_char(t.data_plecare, 'dd-mm-yyyy') data_transport
                    FROM transport t JOIN istoric_camioane_conduse icc ON (t.id_camion = icc.id_camion)
                        JOIN ang a ON (icc.id_angajat = a.id_angajat)
                    WHERE icc.id_camion = c.id_camion
                        and ((icc.data_inceput < t.data_plecare 
                              and t.data_plecare <= NVL(icc.data_sfarsit, sysdate)
                             ) or t.data_plecare is null)
                    )
        FROM camion c JOIN firma f ON (c.id_firma = f.id_firma)
        WHERE upper(c.marca) != 'IVECO' and f.tip_firma = 'TRANSPORT';
        
    -- variabile pentru a retine date despre fiecare camion
    v_id_camion               camion.id_camion%TYPE;
    v_marca_camion            camion.marca%TYPE;
    v_nr_inmatriculare_camion camion.nr_inmatriculare%TYPE;
    v_nume_detinator_camion   firma.nume%TYPE;
    v_cursor_transporturi     refcursor; -- variabila care refera un cursor
    
    -- record pentru a retine informatii minimale despre un transport si sofer
    TYPE rec_transport IS RECORD (
        nume_sofer        angajat.nume%TYPE,
        prenume_sofer     angajat.nume%TYPE,
        salariu           angajat.salariu%TYPE,
        data_transport    varchar2(255)
    );
    rt rec_transport; -- variabila de tip record 
BEGIN
    OPEN c_camion; -- deschide cursorul principal
    LOOP
        FETCH c_camion INTO v_id_camion, v_marca_camion, v_nr_inmatriculare_camion,
            v_nume_detinator_camion, v_cursor_transporturi;
        EXIT WHEN c_camion%NOTFOUND; -- nu mai sunt camioane de afisate
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------'); -- separator
        -- afisam informatiile despre camion
        DBMS_OUTPUT.PUT_LINE('Camionul cu marca '||v_marca_camion||' avand nr. de inmatriculare '
            ||v_nr_inmatriculare_camion||' si este detinut de compania '
            ||v_nume_detinator_camion||'.');
        DBMS_OUTPUT.PUT_LINE('Status transporturi:');
        
        -- pentru fiecare camion afisam informatiile despre status transporturi
        LOOP
            FETCH v_cursor_transporturi INTO rt; -- obtine informatii 
            -- iesi din loop atunci cand nu mai sunt transporturi
            EXIT WHEN v_cursor_transporturi%NOTFOUND;
            
            -- afiseaza informatii despre transport si sofer
            DBMS_OUTPUT.PUT_LINE('Transport in data de '||rt.data_transport||' realizat de '
                ||rt.nume_sofer||' '||rt.prenume_sofer||' care este platit lunar cu '
                ||rt.salariu||'lei.');
        END LOOP;
        
        -- verificam cu rowcount daca nu am gasit date in variabila cursor
        -- semnificand ca nu s-au realizat transporturi cu acest camion inand 
        -- cont de criteriile date
        IF v_cursor_transporturi%rowcount = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Nu au fost realizate transporturi cu acest camion.');
        END IF;
        
        DBMS_OUTPUT.NEW_LINE(); -- separam cu o linie la final
    END LOOP;
    CLOSE c_camion; -- inchidem cursorul
END;

-- 8
FUNCTION func8_info_sofer(
    p_nume angajat.nume%TYPE, p_prenume angajat.prenume%TYPE)
    RETURN tab8_ang_info%rowtype IS
    v_tip_angajat angajat.tip_angajat%TYPE;
    rezultat tab8_ang_info%rowtype;
    nu_este_sofer EXCEPTION;
BEGIN
-- verificam de dinainte tipul angajatului sa stim daca nu se vor intoarce
-- date de la query-ul urmator
    SELECT tip_angajat
    INTO v_tip_angajat
    FROM angajat
    WHERE nume = p_nume and prenume = p_prenume;    

    IF v_tip_angajat <> 'SOFER' THEN -- angajatul nu este sofer, aruncam exceptie
        RAISE p8_exceptions.nu_este_sofer;
    END IF;
    
    -- daca este sofer obtinem datele cerute si le salvam in rezultat
    SELECT a.nr_telefon, a.data_angajare, a.salariu, f.nume, c.marca, c.nr_inmatriculare,
        (SELECT count(id_camion) -- numaram cate camioane a condus soferul folosind o subcerere
         FROM istoric_camioane_conduse sicc
         WHERE sicc.id_angajat = a.id_angajat) nr_camioane_conduse
    INTO rezultat
    FROM angajat a JOIN istoric_camioane_conduse icc ON (a.id_angajat = icc.id_angajat)
        JOIN camion c ON (icc.id_camion = c.id_camion)
        JOIN firma f ON (a.id_firma = f.id_firma)
    WHERE icc.data_sfarsit is null -- null marcheaza faptul ca inca conduce camionul
        and a.nume = p_nume and a.prenume = p_prenume;

    RETURN rezultat;
END;

-- 9 
PROCEDURE proc9_afisare_transport(
    p_nr_inmatriculare camion.nr_inmatriculare%TYPE,
    p_data_plecare varchar2
    ) AS
    TYPE rec_transport_info IS RECORD (
        id_transport                    transport.id_transport%TYPE,
        marca_camion                    camion.marca%TYPE,
        nr_inmatriculare                camion.nr_inmatriculare%TYPE,
        judet_inmatriculare             varchar2(255),
        data_ora_plecare                varchar2(255),
        nr_luni_de_la_transport         number,
        detinator_depozit_plecare       firma.nume%TYPE,
        locatie_depozit_plecare         varchar2(255),
        detinator_depozit_destinatie    firma.nume%TYPE,
        locatie_depozit_destinatie      varchar2(255)
    );
    rez rec_transport_info;
    -- pentru a verifica validatatea primul transport;
    rez_test_valid rec_transport_info;

    -- record pentru a retina fiecare obiect de marfa transportat
    TYPE rec_transport_marfa IS RECORD (
        marfa           lot_marfa.nume%TYPE,
        cantitate       lot_marfa.cantitate%TYPE,
        tip_aliment     varchar2(255)
    );
    -- tabel imbricat pentru a salva marfa din transport
    TYPE tab_marfa IS TABLE OF rec_transport_marfa;
    tm tab_marfa := tab_marfa();
    
    -- exceptie pentru cazul in care gasim un transport dar nu si marfa acestuia
    -- eroare cauzata din lipsa de inserare a marfii la inserarea transportului
    transport_fara_marfa EXCEPTION;
    PRAGMA EXCEPTION_INIT(transport_fara_marfa, -20090);
    
    -- obtine informatiile cerute despre un transport realizat de un camion
    -- dat prin nr. de inmatriculare intr-o zi data
    CURSOR c_transport(
        cp_nr_inmatriculare camion.nr_inmatriculare%TYPE,
        cp_data_plecare varchar2
        ) IS
        WITH depozit_plecare AS
            (SELECT id_depozit, sf.nume detinator, 'Loc: ' || NVL(sl.localitate, '-')
                || ' Str. ' || NVL(sl.strada, '-') || ' Nr. ' || NVL(to_char(sl.nr), '-') locatie
            FROM firma sf JOIN depozit sd ON (sf.id_firma = sd.id_firma)
                          JOIN locatie sl ON (sd.id_locatie = sl.id_locatie)
            ),
            depozit_destinatie AS
            (SELECT id_depozit, sf.nume detinator, 'Loc: ' || NVL(sl.localitate, '-')
                || ' Str. ' || NVL(sl.strada, '-') || ' Nr. ' || NVL(to_char(sl.nr), '-') locatie
             FROM firma sf JOIN depozit sd ON (sf.id_firma = sd.id_firma)
                           JOIN locatie sl ON (sd.id_locatie = sl.id_locatie)
             )
        SELECT t.id_transport,
               c.marca "Marca camion", c.nr_inmatriculare "Nr. inmatriculare", 
               CASE WHEN substr(c.nr_inmatriculare, 0, 2)= 'MM' THEN 'Maramures'
                    WHEN substr(c.nr_inmatriculare, 0, 2)= 'IS' THEN 'Iasi'
                    WHEN substr(c.nr_inmatriculare, 0, 2)= 'CT' THEN 'Constanta'
                    WHEN substr(c.nr_inmatriculare, 0, 1)= 'B' THEN 'Bucuresti'
                    ELSE 'Necunoscut'
               END "Inmatriculat in judetul",
               to_char(t.data_plecare, 'dd-mm-yyyy hh24:mi') "Data si ora plecare",
               round(months_between(sysdate, t.data_plecare)) "Nr. luni de la transport",
               dp.detinator "Detinator depozit plecare", dp.locatie "Locatie depozit plecare", 
               dd.detinator "Detinator depozit destinatie", dd.locatie "Locatie depozit destinatie"
        FROM transport t JOIN camion c ON(t.id_camion = c.id_camion)
                         JOIN firma f ON(c.id_firma = f.id_firma)
                         JOIN depozit_plecare dp ON(dp.id_depozit = t.depozit_plecare) 
                         JOIN depozit_destinatie dd ON(dd.id_depozit = t.depozit_destinatie) 
        WHERE c.nr_inmatriculare = cp_nr_inmatriculare
            AND to_char(t.data_plecare, 'dd-mm-yyyy') = cp_data_plecare;
    
    
    -- obtine toate informatiile despre loturile de marfa al unui transport
    CURSOR c_marfa_transport(p_id_transport transport.id_transport%TYPE) IS 
        SELECT lm.nume "Marfa", lm.cantitate "Cantitate marfa",
            DECODE(lower(lm.nume), 'carne miel', 'alimente', 'carne porc', 'alimente',
            'carne pui', 'alimente', 'lapte', 'alimente', 'rosii', 'alimente',
            'ardei', 'alimente', 'tricouri', 'imbracaminte', 'hanorace', 'imbracaminte',
            'rochii', 'imbracaminte', 'fuste', 'imbracaminte', 'blugi', 'imbracaminte',
            'pantofi', 'incaltaminte', 'necunoscut') "Tip aliment"
        FROM inventar_transport it JOIN lot_marfa lm ON(it.id_lot_marfa = lm.id_lot_marfa)
        WHERE it.id_transport = p_id_transport; 
        
BEGIN
-- obtine date despre transport
    OPEN c_transport(p_nr_inmatriculare, p_data_plecare); -- deschide cursor parametrizat
    FETCH c_transport INTO rez; -- obtine transportul
    FETCH c_transport INTO rez_test_valid; -- mai facem un fetch de test
    -- pentru a verifica daca camionul a realizat mai mult de un transport in
    -- acea zi, daca a realizat doar un transport rowcount va ramane 1
    
    -- nu au fost salvate date nici la primul fetch => nu exista transportul
    -- arunca exceptie
    IF c_transport%rowcount = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;
    -- a fost obtinut mai mult de un transport, transporturile realizate de
    -- camionul dat in ziua data sunt invalide, arunca exceptie custom
    IF c_transport%rowcount > 1 THEN
        RAISE TOO_MANY_ROWS;
    END IF;
    CLOSE c_transport; -- inchide cursor

-- obtine marfa
    OPEN c_marfa_transport(rez.id_transport); -- deschide cursor marfa
    FETCH c_marfa_transport BULK COLLECT INTO tm; -- obtine loturile de marfa
    -- si salveaza-le in tabelul imbricat de marfa
    
    -- daca nu exista loturi de marfa pentru transportul dat atunci transportul
    -- este invalid, arunca exceptie custom fata de cea no_data_found
    IF c_marfa_transport%rowcount = 0 or tm.COUNT() = 0 THEN
        RAISE transport_fara_marfa;
    END IF;
    
    CLOSE c_marfa_transport; -- inchide cursor

    
-- afisare date cerute
    DBMS_OUTPUT.PUT_LINE('Camionul '||rez.nr_inmatriculare||' inmatriculat in judetul '
        ||rez.judet_inmatriculare||' a realizat un transport acum '
        ||rez.nr_luni_de_la_transport||' in data de '
        ||rez.data_ora_plecare);
    DBMS_OUTPUT.PUT_LINE('Camionul a plecat din depozitul detinut de '
        ||rez.detinator_depozit_plecare||' din '||rez.locatie_depozit_plecare
        ||' spre depozitul detinut de '||rez.detinator_depozit_destinatie
        ||' din '||rez.locatie_depozit_destinatie);
    
    DBMS_OUTPUT.PUT_LINE('Marfa transportata de camion:');
    FOR i IN tm.FIRST..tm.LAST LOOP
        DBMS_OUTPUT.PUT_LINE(tm(i).tip_aliment||'-'||
            tm(i).marfa||'-'||tm(i).cantitate);
    END LOOP;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN -- pentru cazul in care nu am gasit transportul
        DBMS_OUTPUT.PUT_LINE('Camionul '||p_nr_inmatriculare||
            ' nu a realizat niciun transport in data de '||p_data_plecare);
    WHEN TOO_MANY_ROWS THEN -- pentru cazul cand un sofer a realizat mai multe transporturi intr-o zi
        DBMS_OUTPUT.PUT_LINE('Camionul '||p_nr_inmatriculare||
            ' a realizat mai multe transporturi in data de '||p_data_plecare
            ||'. Date eronate.');
    WHEN transport_fara_marfa THEN -- daca am gasit transportul dar nu si marfa
        DBMS_OUTPUT.PUT_LINE('Camionul '||p_nr_inmatriculare||
            ' a realizat un transport in data de '||p_data_plecare||
            ' dar nu exista inregistrari pentru marfa transportata. Transport invalid.');
    WHEN OTHERS THEN -- alte exceptiie neprevazute
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
END pack_ex13;
/

-- testam o procedura din pachet
EXECUTE pack_ex13.tracking_proc;