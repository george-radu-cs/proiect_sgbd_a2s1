-- Creati un trigger care sa permita inserari, actualizari si stergeri in
-- tabelul ANGAJAT doar in in zilele de munca in intervalul orar 8 dimineata
-- 6 seara. Triggerul trebuie sa blocheze actualizarile de id-uri sau tip
-- angajat. Folositi-va de application error pentru a trata fiecare caz in parte
CREATE OR REPLACE TRIGGER trig_check_ang
    BEFORE INSERT OR UPDATE OR DELETE ON angajat
BEGIN
    -- verificam sa nu se faca actualizari in weekend (sambata si duminica) 
    -- sau in timpul progrmaului de lucru 8-18
    IF to_char(sysdate, 'DY') IN ('SAT', 'SUN')
        OR (TO_CHAR(SYSDATE,'HH24') NOT BETWEEN 8 AND 18)
    THEN
    -- afiseaza un mesaj de eroare diferit in functie de comanda executata
        IF INSERTING THEN
            RAISE_APPLICATION_ERROR(-20111, 'Inserarea in tabelul de angajati '
                ||'este permisa doar in timpul programului de lucru!');
        ELSIF DELETING THEN
            RAISE_APPLICATION_ERROR(-20112, 'Stergerea din tabelul de angajati '
                ||'este permisa doar in timpul programului de lucru!');
        ELSE
            RAISE_APPLICATION_ERROR(-20113, 'Actualizarile in tabelul de '
                ||'angajati sunt permise doar in timpul programului de lucru!');
        END IF;
    END IF;
    
    -- id-ul unui angajat nu poate fi schimbat - nu vrem sa facem actualizari
    -- recursive in toate tabelele in care apare ca FK
    IF UPDATING('id_angajat') THEN
        RAISE_APPLICATION_ERROR(-20114, 'Nu se poate schimba id-ul unui angajat!');   
    END IF;
    -- nu acceptam sa fie schimbat tipul unui angajat intrucat ar trebuie sa 
    -- rectificam datele inserate pana la momentul actualizarii (daca inainte
    -- un angajat era sofer si avem date de transport despre el atunci ele ar fi
    -- considerate acum invalide deci sterse) nu vrem aces comportament
    IF UPDATING('tip_angajat') THEN
        RAISE_APPLICATION_ERROR(-20114, 'Nu se poate schimba tipul unui angajat!');   
    END IF;
END;

-- exemplu pentru a testa cazul in care azi ar fi zi din weekend
select to_char(to_date('09-01-2022','dd-mm-yyyy'), 'DY')
from dual;


INSERT INTO angajat
VALUES(SEQ_ANG.NEXTVAL, 'Ion', 'Vasile', '0722123456', 
    to_date('11-04-2020 12:00', 'dd-mm-yyyy hh24:mi'), 5000, 1100, 'SOFER', null);

DELETE FROM angajat
WHERE id_angajat = 20000;

UPDATE angajat
SET salariu = 10000
WHERE id_angajat = 20000;

UPDATE ANGAJAT
SET id_angajat = 40000
WHERE id_angajat = 20000;

UPDATE ANGAJAT
SET tip_angajat = 'PAZNIC'
WHERE id_angajat = 20000;

-- comenzi corect in functie de trigger
INSERT INTO angajat
VALUES(SEQ_ANG.NEXTVAL, 'Ion', 'Vasile', '0722123456', 
    to_date('11-04-2020 12:00', 'dd-mm-yyyy hh24:mi'), 5000, 1100, 'SOFER', null);
SELECT * FROM ANGAJAT;
UPDATE angajat
SET salariu = 10000
WHERE id_angajat = 20420;
DELETE FROM ANGAJAT
WHERE id_angajat = 20420;