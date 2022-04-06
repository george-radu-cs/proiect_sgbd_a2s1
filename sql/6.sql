/* Afisati pentru toti soferi toate popasurile in care s-au oprit in ziua in care 
 * s-a oprit pentru prima data un sofer la restaurantul Ceptura din Ploiesti, sa
 * se afiseze daca soferul a venit cu un camion inmatriculat in Prahova sau in
 * alta regiune, numele, prenumele si salariul soferului, numele si tipul 
 * popasului la care s-a oprit, la ce ora a sosit, cat a stat, cati bani a
 * cheltuit la popas, si locatia popasului. Locatia sa fie afisata pe o singura
 * coloana numita Locatie popas. Un sofer cheltuieste la un popas in functie de
 * salariul sau, soferii cu un salariu mai mic de 3000lei inclusiv vor cheltui doar
 * 0.005% din salariu, cei cu salariu intre (3000, 4500] vor chelui 0.01% din 
 * salariu, iar restul vor cheltui 0.015% din salariu. Sa se ordoneze dupa nume
 * si dupa prenume. Din lista de angajati nu afisati nimic pentru ultimii doi din lista. */

-- functie pentru a obtine ziua in care s-a oprit pentru prima data un sofer
-- la restaurantul un popas cu numele si locatia data
CREATE OR REPLACE FUNCTION func_obtine_data(
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

-- subprogram pentru a rezolva cerinta data (am ales procedura intrucat nu trebuie
-- sa intoarcem nimic) - folosim o procedura cu 2 parametrii de intrare(default 
-- sunt de intrare setati) pentru a rezolva cerinta la un caz mai general (indiferent
-- de popas)
CREATE OR REPLACE PROCEDURE proc_track_sofer(
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

-- testam procedura
DECLARE
BEGIN
    proc_track_sofer('Restaurant Ceptura', 'Ploiesti');
END;
-- varianta cu exceptia nu a gasit data
DECLARE
BEGIN
    proc_track_sofer('Restaurant a', 'Ploiesti');
END;