/* Creati un trigger care atunci cand se va realiza update pentru cheile primare
 * din tabelul firma, i.e. id\_firma, va actualiza in toate tabelele in care este
 * cheie externa. Pentru teste faceti copii dupa tabelele deja existente. */

-- facem copii dupa tabele pentru noii triggeri
CREATE TABLE depozit_copy AS SELECT * FROM depozit;
CREATE TABLE camion_copy AS SELECT * FROM camion;
CREATE TABLE angajat_copy AS SELECT * FROM angajat;
CREATE TABLE echipa_paza_copy AS SELECT * FROM echipa_paza;
CREATE TABLE firma_copy AS SELECT * FROM firma;

-- triger care dupa actualizarea pk din tabelul firma actualizeaza fk id_firma
-- in orice tabel care apare
CREATE OR REPLACE TRIGGER update_pk_firma
    AFTER UPDATE OF id_firma ON firma_copy
    FOR EACH ROW
BEGIN
   UPDATE depozit_copy
   SET id_firma = :NEW.id_firma
   WHERE id_firma = :OLD.id_firma;
   
   UPDATE camion_copy
   SET id_firma = :NEW.id_firma
   WHERE id_firma = :OLD.id_firma;
   
   UPDATE angajat_copy
   SET id_firma = :NEW.id_firma
   WHERE id_firma = :OLD.id_firma;
   
   UPDATE echipa_paza_copy
   SET id_firma = :NEW.id_firma
   WHERE id_firma = :OLD.id_firma;
END;

-- teste pentru fiecare tip de firma
-- 100 600 1100
UPDATE firma_copy
SET id_firma = 101
WHERE id_firma = 100;

UPDATE firma_copy
SET id_firma = 601
WHERE id_firma = 600;

UPDATE firma_copy
SET id_firma = 1101
WHERE id_firma = 1100;

-- verificari
select * from firma_copy; 
select * from depozit;
select * from camion_copy;
select * from angajat_copy;
select * from echipa_paza_copy;