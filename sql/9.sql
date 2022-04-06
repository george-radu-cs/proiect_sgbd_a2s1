/* Creati o procedura care primeste nr. de inmatriculare al unui camion si o
 * data de plecare, si obtineti urmatoarele informatii despre transportul
 * realizat de camion in ziua respectiva. Se considera ca un camion nu poate
 * realiza mai multe transporturi in aceeasi zi. Afisati urmatoarele informatii
 * despre transport: nr. de inmatriculare, judetul in care a fost inmatriculat,
 * acum cate luni a fost realizat transportul, data de plecare a camionului din
 * depozitul de plecare, cine detine depozitele de plecare si destinatie si 
 * locatia acestora. Mai afisati o lista cu tipurile de marfa transportata,
 * numele marfii si cantitatea. Tratati toate exceptiile care pot aparea: 
 * 1) nu niciun transport pentru datele oferite
 * 2) camionul a realizat mai multe transporturi in aceeasi zi - invalid nu 
 * poate sa fie in 2 locuri in acelasi timp
 * 3) exista transportul, dar nu exista informatii despre ce marfa transporta
 * 4) alte exceptii */

CREATE OR REPLACE PROCEDURE proc9_afisare_transport(
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


-- 10100 id transport pentru a i sterge marfa transportata pentru a forta o eroare
-- CT12FSD nr inmatriculare data plecare 11-05-2021
select * from transport WHERE id_transport = 10100;
select * from camion where id_camion =15;
select * from inventar_transport where id_transport = 10100;
DELETE FROM inventar_transport WHERE id_transport = 10100;

-- actualizam transportul cu id-ul 10090 setand data de 10010
-- pentru a forta o eroare (evident update-ul nu are sens intrucat acelasi camion
-- nu putea realiza 2 transporturi in locuri diferite in acelasi timp)
UPDATE transport
SET data_plecare = to_date('10-05-2021', 'dd-mm-yyyy')
WHERE id_transport = 10010;
select * from transport where id_camion =25;
select * from camion where id_camion =25;

rollback; -- anulam modificarile facute

-- executa procedura
BEGIN
--    proc9_afisare_transport('MM57RXF', '05-05-2021'); -- ex bun
--    proc9_afisare_transport('MM57RXF', '10-05-2021'); -- no data found - nu am gasit transportul
--    proc9_afisare_transport('CT90MMM', '10-05-2021'); -- to many rows - am gasit mai multe transporturi
    proc9_afisare_transport('CT12FSD', '11-05-2021'); -- custom error - am gasit tarnsportul dar nu si marfa
END;