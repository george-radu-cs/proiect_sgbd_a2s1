/* Pentru fiecare camion sa se afiseze marca, nr. de inmatriculare, numele firmei,
 * care il detine si un status de transporturi. Pentru fiecare transport
 * afisati data de plecare, soferul care a realizat transprotul si cu cate este
 * platit lunar. Daca cu un camion nu au fost realizate transporturi atunci
 * afisati un mesaj corespunzator. Folositi o procedura pentru cerinta de tracking. */

CREATE OR REPLACE PROCEDURE tracking_proc AS
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

-- executa
BEGIN
	tracking_proc();
END;