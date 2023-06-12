CREATE SCHEMA lib;

CREATE TABLE lib.books (
  bookid INT PRIMARY KEY NOT NULL,
  title VARCHAR(20),
  author VARCHAR(20),
  publicationyear DATE,
  status VARCHAR(20)
);

CREATE TRIGGER loaning
ON lib.books
AFTER UPDATE
AS
BEGIN
  IF (UPDATE(status) AND EXISTS(SELECT * FROM inserted WHERE status = 'available'))
  BEGIN
    UPDATE lib.books
    SET status = 'loaned'
    WHERE bookid = bookid;
  END;
END;

UPDATE lib.books
SET status = 'available';

CREATE TABLE lib.members (
  memberid INT PRIMARY KEY NOT NULL,
  name VARCHAR(20),
  address VARCHAR(20),
  contactno VARCHAR(20)
);

CREATE TABLE lib.loans (
  loanid INT PRIMARY KEY NOT NULL,
  bookid INT,
  memberid INT,
  loandate DATE,
  returndate DATE,
  FOREIGN KEY (bookid) REFERENCES lib.books(bookid),
  FOREIGN KEY (memberid) REFERENCES lib.members(memberid)
);

INSERT INTO lib.books (
bookid,
title, 
author,
publicationyear,
status
)
VALUES (
1,
'telemundon',
'christian',
'2020-01-13',
'available'
);


UPDATE lib.books
SET title = 'telemundo'
WHERE title = 'telemundon';


WITH member_borrow_counts AS (
  SELECT memberid, COUNT(*) AS borrow_count
  FROM lib.loans
  GROUP BY memberid
  HAVING COUNT(*) >= 3
)
SELECT m.name
FROM lib.members m
JOIN member_borrow_counts c ON m.memberid = c.memberid;

CREATE FUNCTION dbo.GetOverdueDays (@LoanID INT)
RETURNS INT
AS
BEGIN
  DECLARE @OverdueDays INT;
  
  SELECT @OverdueDays = DATEDIFF(DAY, loandate, GETDATE())
  FROM lib.loans
  WHERE loanid = @LoanID AND returndate IS NULL AND GETDATE() > loandate;
  
  RETURN @OverdueDays;
END;

SELECT dbo.GetOverdueDays(421) AS OverdueDays
FROM lib.loans
WHERE loanid =421;

CREATE VIEW dbo.OverdueLoansView AS
SELECT l.loanid, b.title AS book_title, m.name AS member_name, DATEDIFF(DAY, l.loandate, GETDATE()) AS overdue_days
FROM lib.loans l
JOIN lib.books b ON l.bookid = b.bookid
JOIN lib.members m ON l.memberid = m.memberid
WHERE l.returndate IS NULL AND GETDATE() > l.loandate;

SELECT * FROM dbo.OverdueLoansView;

CREATE TRIGGER more3
ON lib.loans
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @MemberID INT;
    DECLARE @BookCount INT;
    
    SELECT @MemberID = memberid FROM inserted;
    
    SELECT @BookCount = COUNT(*) FROM lib.loans WHERE memberid = @MemberID;
    
    IF @BookCount + (SELECT COUNT(*) FROM inserted) > 3
    BEGIN
        RAISERROR('member cant borrow more than 3 books', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO lib.loans (loanid, bookid, memberid, loandate, returndate)
        SELECT loanid, bookid, memberid, loandate, returndate FROM inserted;
    END
END;
