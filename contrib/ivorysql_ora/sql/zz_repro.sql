--
-- Scratch reproduction script (not for upstream).
--
SHOW ivorysql.compatible_mode;
SELECT version();

CREATE TABLE zz_t (id int PRIMARY KEY);
INSERT INTO zz_t VALUES (1);

-- =====================================================================
-- A. User-defined exceptions without PRAGMA EXCEPTION_INIT
-- =====================================================================

-- A1: WHEN e2 must not catch RAISE e1 (Oracle prints "outer e1")
DECLARE
  e1 EXCEPTION;
  e2 EXCEPTION;
BEGIN
  BEGIN
    RAISE e1;
  EXCEPTION
    WHEN e2 THEN
      RAISE NOTICE 'A1: inner WHEN e2 caught RAISE e1';
  END;
EXCEPTION
  WHEN e1 THEN
    RAISE NOTICE 'A1: outer WHEN e1 caught RAISE e1';
END;
/

-- A2: WHEN e1 must not catch an unrelated RAISE EXCEPTION
DECLARE
  e1 EXCEPTION;
BEGIN
  RAISE EXCEPTION 'plain error';
EXCEPTION
  WHEN e1 THEN
    RAISE NOTICE 'A2: WHEN e1 caught a plain RAISE EXCEPTION';
END;
/

-- A3: package exceptions in two packages
CREATE OR REPLACE PACKAGE zz_pa IS
  e_a EXCEPTION;
END zz_pa;
/
CREATE OR REPLACE PACKAGE zz_pb IS
  e_b EXCEPTION;
END zz_pb;
/
BEGIN
  RAISE zz_pa.e_a;
EXCEPTION
  WHEN zz_pb.e_b THEN
    RAISE NOTICE 'A3: WHEN zz_pb.e_b caught RAISE zz_pa.e_a';
  WHEN zz_pa.e_a THEN
    RAISE NOTICE 'A3: WHEN zz_pa.e_a caught RAISE zz_pa.e_a';
END;
/

-- A4: unhandled user-defined exception as seen by the client
\set VERBOSITY verbose
DECLARE
  e1 EXCEPTION;
BEGIN
  RAISE e1;
END;
/
\set VERBOSITY default

-- =====================================================================
-- B. PRAGMA EXCEPTION_INIT with Oracle error numbers
-- =====================================================================

-- B1: ORA-00001 -> unique violation
DECLARE
  e_dup EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_dup, -1);
BEGIN
  INSERT INTO zz_t VALUES (1);
EXCEPTION
  WHEN e_dup THEN
    RAISE NOTICE 'B1: EXCEPTION_INIT(-1) caught the unique violation';
END;
/

-- B2: ORA-01476 -> division by zero
DECLARE
  e_div EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_div, -1476);
  n NUMBER;
BEGIN
  n := 1 / 0;
EXCEPTION
  WHEN e_div THEN
    RAISE NOTICE 'B2: EXCEPTION_INIT(-1476) caught division by zero';
END;
/

-- B3: 100 -> no data found (baseline with the predefined name first)
DECLARE
  v int;
BEGIN
  SELECT id INTO v FROM zz_t WHERE id = -1;
  RAISE NOTICE 'B3 baseline: SELECT INTO returned without error, v=%', v;
EXCEPTION
  WHEN no_data_found THEN
    RAISE NOTICE 'B3 baseline: WHEN no_data_found caught it';
END;
/
DECLARE
  e_nd EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_nd, 100);
  v int;
BEGIN
  SELECT id INTO v FROM zz_t WHERE id = -1;
EXCEPTION
  WHEN e_nd THEN
    RAISE NOTICE 'B3: EXCEPTION_INIT(100) caught no_data_found';
END;
/

-- B4: unhandled EXCEPTION_INIT(-20002) as seen by the client
\set VERBOSITY verbose
DECLARE
  e EXCEPTION;
  PRAGMA EXCEPTION_INIT(e, -20002);
BEGIN
  RAISE e;
END;
/
\set VERBOSITY default

-- B5: SQLSTATE/SQLERRM inside WHEN OTHERS
DECLARE
  e EXCEPTION;
  PRAGMA EXCEPTION_INIT(e, -20002);
BEGIN
  RAISE e;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'B5: SQLSTATE=[%] SQLERRM=[%]', SQLSTATE, SQLERRM;
END;
/

-- =====================================================================
-- C. Oracle predefined exception names
-- =====================================================================

-- C0: PostgreSQL name works (baseline)
DECLARE
  n NUMBER;
BEGIN
  n := 1 / 0;
EXCEPTION
  WHEN division_by_zero THEN
    RAISE NOTICE 'C0: WHEN division_by_zero caught it';
END;
/

DECLARE
  n NUMBER;
BEGIN
  n := 1 / 0;
EXCEPTION
  WHEN ZERO_DIVIDE THEN
    RAISE NOTICE 'C1: WHEN ZERO_DIVIDE caught it';
END;
/

BEGIN
  INSERT INTO zz_t VALUES (1);
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE NOTICE 'C2: WHEN DUP_VAL_ON_INDEX caught it';
END;
/

DECLARE
  n NUMBER;
BEGIN
  n := to_number('abc');
EXCEPTION
  WHEN INVALID_NUMBER THEN
    RAISE NOTICE 'C3: WHEN INVALID_NUMBER caught it';
END;
/

DECLARE
  v varchar2(3);
BEGIN
  v := 'abcdef';
EXCEPTION
  WHEN VALUE_ERROR THEN
    RAISE NOTICE 'C4: WHEN VALUE_ERROR caught it';
END;
/

DECLARE
  CURSOR c IS SELECT 1 FROM dual;
BEGIN
  OPEN c;
  OPEN c;
EXCEPTION
  WHEN CURSOR_ALREADY_OPEN THEN
    RAISE NOTICE 'C5: WHEN CURSOR_ALREADY_OPEN caught it';
END;
/

DECLARE
  CURSOR c IS SELECT 1 FROM dual;
  x int;
BEGIN
  FETCH c INTO x;
EXCEPTION
  WHEN INVALID_CURSOR THEN
    RAISE NOTICE 'C6: WHEN INVALID_CURSOR caught it';
END;
/

-- C7: which SQLSTATE each Oracle situation raises today
DECLARE
  n NUMBER;
BEGIN
  n := 1 / 0;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 zero_divide: % %', SQLSTATE, SQLERRM;
END;
/
BEGIN
  INSERT INTO zz_t VALUES (1);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 dup_val_on_index: % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  n NUMBER;
BEGIN
  n := to_number('abc');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 invalid_number (PL/SQL assignment): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  n NUMBER;
BEGIN
  SELECT to_number('abc') INTO n FROM dual;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 invalid_number (SQL): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  v varchar2(3);
BEGIN
  v := 'abcdef';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 value_error (string too long): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  n NUMBER(2);
BEGIN
  n := 12345;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 value_error (number precision): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  CURSOR c IS SELECT 1 FROM dual;
BEGIN
  OPEN c;
  OPEN c;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 cursor_already_open: % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  CURSOR c IS SELECT 1 FROM dual;
  x int;
BEGIN
  FETCH c INTO x;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 invalid_cursor (fetch unopened): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  CURSOR c IS SELECT 1 FROM dual;
BEGIN
  CLOSE c;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 invalid_cursor (close unopened): % %', SQLSTATE, SQLERRM;
END;
/
DECLARE
  v int;
BEGIN
  SELECT id INTO v FROM (SELECT 1 AS id FROM dual UNION ALL SELECT 2 FROM dual) s;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'C7 too_many_rows: % %', SQLSTATE, SQLERRM;
END;
/

-- =====================================================================
-- F. SQLCODE inside an exception handler
-- =====================================================================
BEGIN
  RAISE EXCEPTION 'x';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'F1: SQLCODE=%', SQLCODE;
END;
/

-- =====================================================================
-- D. Known open issues
-- =====================================================================

-- #2016 regexp_instr
SELECT regexp_instr('abcabc', 'c', 1) AS "#2016 expect 3" FROM dual;
SELECT regexp_instr('abcabc', 'c', 1, 2) AS "#2016 expect 6" FROM dual;
SELECT regexp_instr('abc', 'c*', 1, 1) AS "#2016 expect 1" FROM dual;
SELECT regexp_instr('abcabc', '(a)(b)', 1, 1, 1, 'i', 2) AS "#2016 expect 3" FROM dual;
SELECT regexp_instr('abcabc', 'bc', 1) AS "multi-char expect 2" FROM dual;

-- #2018 to_number / to_char with $
SELECT to_number('123', '$999') FROM dual;
SELECT to_char(-123, '$999') AS "expect -$123" FROM dual;
SELECT to_char(1, '$999') AS "expect $1" FROM dual;

-- #2020 power / sqrt precision
SELECT power(3, 50) AS "expect 717897987691852588770249" FROM dual;
SELECT pg_typeof(sqrt(2)) FROM dual;

-- #1876 integer division
SELECT 1 / 3 AS "expect .333...", 10 / 4 AS "expect 2.5" FROM dual;

-- #1763 instr (position = 0 is handled by open PR #3030)
SELECT instr('abcabc', 'abc', 0) AS "pos0 expect 0" FROM dual;
SELECT instr('abcabc', 'b', 1, 0) AS "occ0 expect ORA-01428" FROM dual;
SELECT instr('abcabc', 'b', 1, -1) AS "occ-1 expect ORA-01428" FROM dual;
SELECT instr('abcabc', 'b', -2147483647) AS "near INT_MIN expect 0" FROM dual;
-- keep last: may crash the backend
SELECT instr('abcabc', 'b', -2147483648) AS "INT_MIN expect 0" FROM dual;
SELECT 'still connected' AS status FROM dual;
