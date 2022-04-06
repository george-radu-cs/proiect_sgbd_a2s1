/* Definiti un trigger care sa verifice pentru tabelul istoric_popasuri
 * validitatea datelor. Data de plecare nu poate sa fie mai mica decat
 * data de sosire a unui sofer la un popas. La update nu putem modifica
 * decat cele 2 dati, nicio alta coloana. */

CREATE OR REPLACE TRIGGER trig_ist_pop
    BEFORE UPDATE OR INSERT on istoric_popasuri
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.data_plecare is not null 
            and :NEW.data_sosire >= :NEW.data_plecare THEN
            RAISE_APPLICATION_ERROR(-20100, 
                'Data de plecare nu poate fi mai mica decat data de sosire');
        END IF;
    ELSE -- UPDATE
        IF :NEW.id_istoric_popas <> :OLD.id_istoric_popas THEN
            RAISE_APPLICATION_ERROR(-20101, 'id_istoric_popas nu poate fi modificat.');
        END IF;
        IF :NEW.id_popas <> :OLD.id_popas THEN
            RAISE_APPLICATION_ERROR(-20101, 'id_popas nu poate fi modificat.');
        END IF;
        IF :NEW.id_angajat <> :OLD.id_angajat THEN
            RAISE_APPLICATION_ERROR(-20101, 'id_angajat nu poate fi modificat.');
        END IF;
        
        -- s-a actualizat data de plecare
        IF :NEW.data_plecare <> :OLD.data_plecare THEN
            -- s-a actualizat si data de sosire
            IF :OLD.data_sosire <> :NEW.data_sosire THEN
                IF :NEW.data_sosire > :NEW.data_plecare THEN
                        RAISE_APPLICATION_ERROR(-20100, 
                        'Data de plecare nu poate fi mai mica decat data de sosire');
                END IF;
            ELSE -- nu s-a actualizat data de sosire
                IF :OLD.data_sosire > :NEW.data_plecare THEN
                        RAISE_APPLICATION_ERROR(-20100, 
                        'Data de plecare nu poate fi mai mica decat data de sosire');
                END IF;
            END IF;
        ELSE -- data de plecare a ramas aceeasi
            IF :NEW.data_sosire > :OLD.data_plecare THEN
                    RAISE_APPLICATION_ERROR(-20100, 
                    'Data de plecare nu poate fi mai mica sau decat data de sosire');
            END IF;
        END IF;
        
    END IF;
END;

INSERT INTO istoric_popasuri
VALUES(50, 180, 20000, to_date('04-10-2021', 'dd-mm-yyyy'), to_date('04-10-2021', 'dd-mm-yyyy'));
INSERT INTO istoric_popasuri
VALUES(50, 180, 20000, to_date('04-10-2021', 'dd-mm-yyyy'), to_date('03-10-2021', 'dd-mm-yyyy'));
INSERT INTO istoric_popasuri
VALUES(50, 180, 20000, to_date('04-10-2021', 'dd-mm-yyyy'), to_date('05-10-2021', 'dd-mm-yyyy'));
INSERT INTO istoric_popasuri
VALUES(50, 180, 20000, to_date('05-10-2021', 'dd-mm-yyyy'), null);

-- exceptie nu putem actualiza id_istoric_popas
UPDATE istoric_popasuri
SET id_istoric_popas = 15
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- exceptie nu putem actualiza id_popas
UPDATE istoric_popasuri
SET id_popas = 15
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- exceptie nu putem actualiza id_angajat
UPDATE istoric_popasuri
SET id_angajat = 15
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- actualizam doar data de sosire
UPDATE istoric_popasuri
SET data_sosire = to_date('05-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- actualizam doar data de plecare - aceeasi zi
UPDATE istoric_popasuri
SET data_plecare = to_date('05-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- ex bun update doar data plecare - data plecare mai mare
UPDATE istoric_popasuri
SET data_plecare = to_date('06-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- modificam data de plecare si o facem mai mica decat data de sosire
UPDATE istoric_popasuri
SET data_plecare = to_date('05-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- ex exceptie update ambele dati
UPDATE istoric_popasuri
SET data_plecare = to_date('05-10-2021', 'dd-mm-yyyy'),
    data_sosire = to_date('10-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');

-- ex bun update ambele dati
UPDATE istoric_popasuri
SET data_plecare = to_date('06-10-2021', 'dd-mm-yyyy'),
    data_sosire = to_date('05-10-2021', 'dd-mm-yyyy')
WHERE data_sosire = to_date('05-10-2021', 'dd-mm-yyyy');