/* Creati o functie care sa intoarca urmatoarele date despre un sofer dat prin 
 * 2 parametrii de intrare (numele si prenumele sau): nr. de telefon pentru a 
 * putea fi contact, cand a fost angajat, la ce firma lucreaza, ce marca de
 * camion conduce acum, nr. de inmatriculare si cate camioane a condus pana acum.
 * Tratati urmatoarele cazuri prin exceptii: 
 * - nu a fost gasit angajatul 
 * - exista mai multi angajati cu acelasi nume
 * - angajatul exista dar nu este sofer
 * - celelate exceptii care pot aparea generic, cod de eroare si mesajul erorii */

-- tabel ajutator pentru a intoarce un tip de date din functie
CREATE TABLE tab8_ang_info (
    nr_telefon_ang          varchar2(25),
    data_angajarre          date,
    salariu_angajat         number(10),
    nume_firma              varchar2(15) ,
    marca_camion            varchar2(10),
    nr_inmatriculare        varchar2(10),
    nr_camioane_conduse     number
);

-- creeaza intr-un pachet eroarea pentru a o putea arunca in functie si a o
-- prinde in blocul in care apelam functia. Facem acest lucru intrucat daca
-- definim exceptia in functie ea este declarata doar in blocul privat al functiei
-- si daca incercam sa o definim si in blocul apelant ea nu va fi considerata
-- aceeasi si va intra pe cazul others;
CREATE OR REPLACE PACKAGE p8_exceptions
AS
    nu_este_sofer EXCEPTION;
    PRAGMA EXCEPTION_INIT(nu_este_sofer, -20080);
END;
/

CREATE OR REPLACE FUNCTION func8_info_sofer(
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

DECLARE
    v_ang tab8_ang_info%rowtype;
BEGIN 
    v_ang := func8_info_sofer('Ion', 'Vasile'); -- ex bun
--    v_ang := func8_info_sofer('Andrei', 'Vasile'); -- no data found
--    v_ang := func8_info_sofer('Ion', 'Catalin'); -- too many rows
--    v_ang := func8_info_sofer('Andrei', 'David'); -- exceptie speciala nu este sofer

-- o simpla afisare a datelor pentru a verifica cazul bun    
    DBMS_OUTPUT.PUT_LINE('Soferul poate fi contact la nr '||v_ang.nr_telefon_ang||
        '. Lucreaza pentru firma '||v_ang.nume_firma||' unde primeste salariul de '
        ||v_ang.salariu_angajat||'. A condus in total '||v_ang.nr_camioane_conduse
        ||' pana acum. In momentul de fata conduce un camion '||v_ang.marca_camion
        ||' cu nr. de inmatriculare '||v_ang.nr_inmatriculare);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nu au putut fi obtinute informatii despre soferul dat');
    WHEN TOO_MANY_ROWS THEN 
        DBMS_OUTPUT.PUT_LINE('Au fost gasiti mai multi angajati cu numele dat');
    WHEN p8_exceptions.nu_este_sofer THEN
        DBMS_OUTPUT.PUT_LINE('Angajatul dat nu este sofer. Nu putem intoarce informatii despre el.');
    WHEN others THEN
        DBMS_OUTPUT.PUT_LINE('Cod eroare: '||SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Mesaj erorare: '|| SQLERRM);
END;
