/* Creati un tabel audit in care sa salvati recorduri de tipul: nume baza de date,
 * user, eveniment realizat, tipul obiectului din dictionar pe care s-a realizat
 * evenimentul, numele obiectului din dictionar, un timestamp pentru cand a fost
 * realizat evnimentul. Tabelul va fi populat folosind un trigger de tip LDD care
 * va obtine datele necesare si le va salva in tabel. Dupa compilarea trigger-ului
 * testati-l pe mai multe tipuri de obiecte. */

CREATE TABLE audit_user (
    nume_bd               VARCHAR2(50), 
    user_logat            VARCHAR2(30), 
    eveniment             VARCHAR2(20), 
    tip_obiect_referit    VARCHAR2(30), 
    nume_obiect_referit   VARCHAR2(30), 
    data                  TIMESTAMP(3)
); 

CREATE OR REPLACE TRIGGER audit_schema 
  AFTER CREATE OR DROP OR ALTER ON SCHEMA 
BEGIN 
  INSERT INTO audit_user 
  VALUES (SYS.DATABASE_NAME, SYS.LOGIN_USER,  
      SYS.SYSEVENT, SYS.DICTIONARY_OBJ_TYPE,  
      SYS.DICTIONARY_OBJ_NAME, SYSTIMESTAMP(3)); 
END; 
/

CREATE TABLE test (id varchar2(25));
ALTER TABLE test ADD coloana_noua varchar2(25);

desc test;

CREATE INDEX index_test ON test(id);
DROP INDEX index_test;

DROP table test;

CREATE OR REPLACE TYPE o IS OBJECT (t varchar(2));
DROP TYPE o;

select * from audit_user;