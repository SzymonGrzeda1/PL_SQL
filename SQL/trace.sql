grant SELECT_CATALOG_ROLE to hr;
grant SELECT ANY DICTIONARY to hr;

explain plan for
select count(*) from f_fact where d1 = 2 and (d2 = 3 or d3 = 4) and d4 IN (10,11,12);

select * from table(dbms_xplan.display);
