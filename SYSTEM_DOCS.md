# תיעוד מערכת M.A.B-ERP

> **מסמך זה מתאר את כל המערכת בשפה פשוטה.**
> עדכן אותו בכל שינוי.

---

## תוכן עניינים

1. [סקירה כללית](#1-סקירה-כללית)
2. [טכנולוגיות בשימוש](#2-טכנולוגיות-בשימוש)
3. [מבנה הקבצים](#3-מבנה-הקבצים)
4. [מסכי המערכת](#4-מסכי-המערכת)
5. [מסד הנתונים — טבלאות](#5-מסד-הנתונים--טבלאות)
6. [לוגיקה עסקית עיקרית](#6-לוגיקה-עסקית-עיקרית)
7. [פונקציות JavaScript — רשימה מוסברת](#7-פונקציות-javascript--רשימה-מוסברת)
8. [מספור אוטומטי](#8-מספור-אוטומטי)
9. [הדפסה](#9-הדפסה)
10. [API רשות המסים — מספר הקצאה](#10-api-רשות-המסים--מספר-הקצאה)
11. [מיגרציות DB](#11-מיגרציות-db)
12. [מילון מונחים טכניים](#12-מילון-מונחים-טכניים)

---

## 1. סקירה כללית

מערכת **M.A.B-ERP** היא מערכת ניהול עסקי (ERP) בסגנון Priority.
המערכת בנויה כקובץ HTML יחיד (`admin/dashboard.html`) שמכיל את כל הממשק, העיצוב (CSS) והלוגיקה (JavaScript).

**מה המערכת עושה:**
- ניהול לקוחות, פרויקטים ומשימות
- ניהול מוצרים (קטלוג)
- הצעות מחיר → חשבוניות
- הדפסת מסמכים (הצגה/הדפסה/שליחה)
- קבלת מספר הקצאה מרשות המסים (API)
- יומן אירועים
- לוג פעילות
- דוחות
- פורטל לקוח (גישה חיצונית ללקוח לצפות בפרויקטים שלו)

---

## 2. טכנולוגיות בשימוש

| רכיב | טכנולוגיה | הסבר |
|------|-----------|-------|
| ממשק המשתמש | HTML + CSS + JavaScript ואניל | ללא Framework — הכל ידני |
| גופן | Inter (Google Fonts) | גופן אנגלי מודרני |
| מסד נתונים | Supabase (PostgreSQL) | שרת DB בענן, דרך REST API |
| אימות משתמשים | Supabase Auth | התחברות עם אימייל + סיסמה |
| הדפסה | `window.print()` בחלון חדש | ללא ספרייה חיצונית |
| יצוא PDF (דוחות) | html2pdf.js | דרך CDN |
| API חיצוני | ITA (רשות המסים) | OAuth 2.0 + JSON |
| אחסון | GitHub Pages | האתר עצמו מתאחסן ב-GitHub |

**תצורת Supabase:** מוגדרת בקובץ `shared/config.js` (URL + ANON KEY).

---

## 3. מבנה הקבצים

```
project-manager/
│
├── admin/
│   └── dashboard.html          ← הקובץ הראשי (כל המערכת)
│
├── shared/
│   └── config.js               ← מפתח Supabase + URL
│
├── portal/
│   └── index.html              ← פורטל לקוח (גישה ציבורית)
│
├── supabase/
│   ├── schema.sql              ← הגדרת כל הטבלאות + RLS + Triggers
│   └── migration_ita_api.sql  ← הוספת עמודות ITA ל-company
│
└── SYSTEM_DOCS.md             ← המסמך הזה
```

---

## 4. מסכי המערכת

כל מסך הוא `<section>` עם ID בפורמט `section-<שם>`.
המסך הפעיל מקבל class="active".

### מסכי ERP מלאים (סגנון Priority)

אלו מסכים עם **שני חלקים**:
- **Header / Master** — שורת המסמך הראשית (למשל: לקוח, תאריך, סטטוס)
- **Lines / Son** — שורות הפירוט מטה (למשל: מוצרים בהצעת מחיר)

| מסך | ID | תיאור |
|-----|-----|-------|
| פרויקטים | `section-projects` | ניהול פרויקטים. Son tabs: משימות + תיאור |
| משימות | `section-tasks` | ניהול משימות. Son tabs: תיאור |
| מוצרים | `section-parts` | קטלוג מוצרים/שירותים |
| הצעות מחיר | `section-quotes` | הצעות מחיר + שורות |
| חשבוניות | `section-invoices` | חשבוניות + שורות |

### מסך לקוחות (Master-Detail)

מסך `section-clients` — רשימה בצד שמאל, פרטים בצד ימין.
- Tab "חיבורים" — פרטי VPN / ERP של הלקוח
- Tab "פרויקטים" — פרויקטים של הלקוח
- Tab "היסטוריה" — לוג פעילות

### מסכים נוספים

| מסך | ID | תיאור |
|-----|-----|-------|
| דף הבית | `section-dashboard` | סטטיסטיקות + פעילות אחרונה |
| יומן | `section-calendar` | יומן אירועים חודשי |
| דוחות | `section-reports` | טבלת פרויקטים עם יצוא PDF |
| סטטוסים | `section-statuses` | עריכת סטטוסים מותאמים אישית |
| כלי מנהל | `section-admin-tools` | שאילתות SQL חופשיות |
| נתוני חברה | `section-company` | הגדרות עסק: שם, לוגו, מע"מ, ITA |
| אבטחה | `section-security` | ניהול MFA (אימות דו-שלבי) |

---

## 5. מסד הנתונים — טבלאות

**כללי שמות:** ללא קו תחתון, PK בפורמט `<שם-טבלה>id`. תאריכים: `cdate`=יצירה, `udate`=עדכון, `odate`=תאריך פתיחה.

### `customers` — לקוחות

| עמודה | סוג | תיאור |
|-------|-----|-------|
| custid | UUID PK | מזהה ייחודי |
| custname | TEXT | שם מלא |
| email | TEXT | אימייל |
| phone | TEXT | טלפון |
| custcomp | TEXT | שם החברה |
| address | TEXT | כתובת |
| notes | TEXT | הערות |
| status | TEXT | active / inactive |
| token | UUID | לפורטל הלקוח (קישור אישי) |
| custnum | TEXT | מספר לקוח אוטומטי (C00001) |

### `projects` — פרויקטים

| עמודה | סוג | תיאור |
|-------|-----|-------|
| projid | UUID PK | מזהה |
| custid | UUID FK | קשור ל-customers |
| projname | TEXT | שם פרויקט |
| projdes | TEXT | תיאור (markdown חופשי) |
| status | TEXT | planning / active / paused / completed / cancelled |
| priority | TEXT | low / medium / high |
| sdate/edate | DATE | תאריך התחלה/סיום |
| budget | DECIMAL | תקציב |
| progress | INTEGER | אחוז התקדמות (0-100) |
| projnum | TEXT | מספר אוטומטי (P000001) |

### `tasks` — משימות

| עמודה | סוג | תיאור |
|-------|-----|-------|
| taskid | UUID PK | מזהה |
| projid | UUID FK | קשור ל-projects |
| taskname | TEXT | כותרת |
| taskdes | TEXT | תיאור |
| status | TEXT | pending / in_progress / completed / blocked |
| priority | TEXT | low / medium / high / urgent |
| duedate | DATE | תאריך יעד |
| assignto | TEXT | שם אחראי |
| tasknum | TEXT | מספר אוטומטי (M000001) |

### `parts` — מוצרים / שירותים

| עמודה | סוג | תיאור |
|-------|-----|-------|
| partid | TEXT PK | קוד מוצר (ידני או PR00001) |
| partname | TEXT | שם מוצר (ייחודי) |
| partdes | TEXT | תיאור |

### `quotes` — הצעות מחיר

| עמודה | סוג | תיאור |
|-------|-----|-------|
| quoteid | UUID PK | מזהה |
| custid | UUID FK | לקוח |
| quotenum | TEXT | מספר (QT26000001) |
| qdate | DATE | תאריך |
| validdate | DATE | בתוקף עד |
| ponum | TEXT | מספר הזמנה של לקוח |
| status | TEXT | draft / sent / approved / rejected / cancelled |
| subtotal | DECIMAL | סכום לפני מע"מ |
| vatamt | DECIMAL | סכום מע"מ |
| total | DECIMAL | סכום כולל |
| invoiced | BOOLEAN | האם הפכה לחשבונית |

### `quote_lines` — שורות הצעת מחיר

| עמודה | סוג | תיאור |
|-------|-----|-------|
| lineid | UUID PK | מזהה |
| quoteid | UUID FK | הצעת מחיר |
| linenum | INT | מספר שורה |
| partid | TEXT FK | מוצר (אופציונלי) |
| linedes | TEXT | תיאור חופשי |
| qty | DECIMAL | כמות |
| unitprice | DECIMAL | מחיר יחידה |
| discount | DECIMAL | הנחה % |
| linetotal | DECIMAL | סה"כ שורה |

### `invoices` — חשבוניות

| עמודה | סוג | תיאור |
|-------|-----|-------|
| invid | UUID PK | מזהה |
| invtempnum | TEXT | מספר טיוטה (T260001) |
| invfinalnum | TEXT | מספר סופי (INV260001) |
| invnum | TEXT | המספר הנוכחי הפעיל |
| status | TEXT | draft / final / cancelled |
| idate | DATE | תאריך חשבונית |
| custid | UUID FK | לקוח |
| quoteid | UUID FK | הצעת מחיר (אופציונלי) |
| subtotal | DECIMAL | לפני מע"מ |
| vatamt | DECIMAL | מע"מ |
| total | DECIMAL | סה"כ |
| allocnum | VARCHAR(20) | מספר הקצאה מרשות המסים |
| printed | BOOLEAN | האם הודפסה |

### `invoice_lines` — שורות חשבונית

זהה ל-`quote_lines` עם PK=`ilineid` ו-FK=`invid`.

### `company` — נתוני החברה

| עמודה | תיאור |
|-------|-------|
| compname | שם העסק |
| ownname | שם הבעלים |
| taxnum | ח.פ / ע.מ (9 ספרות) |
| phone/email/website | פרטי קשר |
| addr1/addr2/city/zip | כתובת |
| bankdet | פרטי בנק |
| logo | תמונת הלוגו (Base64) |
| vatrate | שיעור מע"מ (ברירת מחדל 17) |
| taxconst | קבוע מסים (שדה ישן) |
| ita_token | Bearer Token לרשות המסים |
| ita_sandbox | true=בדיקות, false=ייצור |
| isdemo | האם המערכת במצב הדגמה |

### `client_connections` — חיבורי VPN/ERP ללקוח

פרטי גישה של הלקוח: VPN, כתובת שרת, שם משתמש, סיסמה, URL, פורט.

### `activity_log` — לוג פעילות

| עמודה | תיאור |
|-------|-------|
| etype | סוג ישות: client/project/task/part/quote/invoice |
| eid | מזהה הרשומה |
| ename | שם הרשומה |
| action | פעולה: created/updated/deleted/... |

### `statuses` — סטטוסים מותאמים

הגדרת סטטוסים לפרויקטים/משימות/לקוחות עם צבע ותצוגה.

### `profiles` — פרופיל משתמשים

| עמודה | תיאור |
|-------|-------|
| id | UUID (זהה ל-auth.users) |
| role | admin / client |

---

## 6. לוגיקה עסקית עיקרית

### מחזור חיים של חשבונית

```
draft (טיוטה) → [סגירה] → final (סופית)
draft (טיוטה) → [מחיקה] → נמחק
final (סופית) → [ביטול] → cancelled (מבוטלת)
```

**סגירת חשבונית (`invClose`):**
1. בדיקה שהחשבונית בסטטוס `draft`
2. אם `subtotal >= ₪5,000` ואין `allocnum` → קריאה ל-ITA API → שמירת `allocnum`
3. קריאה ל-RPC `close_invoice()` בDB → מייצרת מספר INV + מחליפה לסטטוס `final`

**הדפסת חשבונית:**
- הדפסה ראשונה של `final` = "מקור" + מסמן `printed=true`
- הדפסות נוספות = "העתק"
- חשבונית מבוטלת = כותרת מים "בוטל"

### מחזור חיים של הצעת מחיר

```
draft → sent → approved → [פתח חשבונית] → invoiced=true
draft/sent → rejected / cancelled
```

**פתיחת חשבונית מהצעה (`openInvFromQuote`):**
- מדפיס שורות הצעה לחשבונית חדשה
- מסמן `invoiced=true` על ההצעה **רק לאחר שמירה מוצלחת** של החשבונית

### Guard — חסימת Son tabs

אם אין רשומה פתוחה (למשל, עוד לא נבחר פרויקט), tabs הבן חסומים.
לוגיקה: ב-`showSection` + בכל `loadXxxById`.

### Tab bar — מסכים פתוחים

שורה עליונה שמציגה את כל הישויות הפתוחות (לקוח/פרויקט/משימה/מוצר/הצעה/חשבונית).
מנוהל ע"י `renderTabsBar()` ו-`closeTab()`.

### go_live — העלאה לאוויר

כפתור ב"נתוני חברה" שמוחק את כל נתוני ההדגמה ומאפס את הסדרות (sequences).
**סדר המחיקה חשוב** (FK constraints):
1. invoice_lines → invoices → quote_lines → quotes → client_connections → activity_log → customers → parts

---

## 7. פונקציות JavaScript — רשימה מוסברת

### פונקציות כלליות

| פונקציה | מה היא עושה |
|---------|-------------|
| `showSection(name)` | מעבר למסך — מסתיר את הנוכחי, מציג את החדש, עדכון סרגל ניווט |
| `showToast(msg, type)` | הודעת popup קטנה בפינה (success/error/warning/info) |
| `renderTabsBar()` | מרנדר את שורת הטאבים של המסכים הפתוחים |
| `closeTab(section)` | סוגר טאב + חוזר לדף הבית |
| `logActivity(type, id, name, action)` | שומר רשומה ב-`activity_log` |
| `checkAuth()` | בודק אם יש משתמש מחובר ושהוא admin |
| `logout()` | התנתקות |

### לקוחות

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadClients()` | טוען רשימת לקוחות מה-DB |
| `selectCustomer(custid)` | בוחר לקוח ברשימה + מציג פרטיו |
| `renderCustomerDetail(c)` | מציג את הפרטים בפאנל ימין |
| `loadCustomerConnections(custid)` | טוען חיבורי VPN של הלקוח |
| `saveClient(e)` | שומר/יוצר לקוח |
| `toggleClientStatus(id, status)` | מחליף active/inactive |

### פרויקטים

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadProjects()` | טוען פרויקטים מה-DB לתוך `projState.list` |
| `projNew()` | מאפס את הטופס לפרויקט חדש |
| `projNav(dir)` | ניווט (ראשון/קודם/הבא/אחרון) |
| `loadProjById(projid, idx)` | טוען פרויקט ספציפי לפי ID |
| `saveProjHeader()` | שומר את נתוני header הפרויקט |
| `projDelete()` | מוחק פרויקט (אחרי אישור) |
| `toggleProjSearchMode()` | מפעיל/מכבה מצב חיפוש |

### משימות

זהה לפרויקטים — אותו פטרן עם prefix `task` במקום `proj`.

### מוצרים

זהה לפרויקטים — prefix `part`. מוצרים שנוצרים/נמחקים מתועדים ב-`activity_log`.

### הצעות מחיר

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadQuotes()` | טוען הצעות |
| `quoteNew()` | הצעה חדשה |
| `quoteNav(dir)` | ניווט |
| `loadQuoteById(quoteid, idx)` | טוען הצעה ספציפית |
| `saveQuoteHeader()` | שומר header |
| `buildLineRow(line, idx, isNew, locked)` | בונה שורת HTML לטבלת הפירוט |
| `linePartChange(sel, idx)` | בחירת מוצר בשורה — ממלא מחיר |
| `lineFieldChange(el, idx, field)` | שינוי ערך שדה בשורה |
| `recalcLine(idx)` | מחשב מחדש `linetotal` לשורה |
| `recalcTotals()` | מחשב subtotal/vat/total בתחתית |
| `saveLine(idx)` | שומר שורה ל-DB |
| `deleteLine(lineid, idx)` | מוחק שורה |
| `quotePrint(previewOnly)` | פותח חלון הדפסה/תצוגה מקדימה |
| `openInvFromQuote()` | פותח חשבונית חדשה מתוך ההצעה |

### חשבוניות

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadInvoices()` | טוען חשבוניות |
| `invNew()` | חשבונית חדשה |
| `invNav(dir)` | ניווט |
| `loadInvById(invid, idx)` | טוען חשבונית |
| `saveInvHeader()` | שומר header |
| `invClose()` | סוגר חשבונית (draft→final) + ITA אם נדרש |
| `invVoid()` | מבטל חשבונית (final→cancelled) |
| `invDelete()` | מוחק טיוטה |
| `invPrint(previewOnly)` | הדפסת חשבונית |
| `_setInvActionBtns(hasRecord, isDraft)` | שולט אילו כפתורים מוצגים |
| `setInvLockedUI(locked, msg)` | נועל/מסיר נעילה של טופס (final/cancelled) |

### נתוני חברה

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadCompany()` | טוען נתוני חברה מה-DB |
| `saveCompany()` | שומר נתוני חברה |
| `confirmGoLive()` | dialog אישור לפני מחיקת נתוני דמו |
| `goLive()` | מריץ RPC `go_live()` ב-DB |
| `handleLogoUpload(input)` | העלאת תמונה → Base64 |

### דוחות

| פונקציה | מה היא עושה |
|---------|-------------|
| `loadReports()` | טוען נתוני דוח |
| `renderReportsTable()` | מרנדר טבלת פרויקטים |
| `exportPDF()` | ייצוא ל-PDF (html2pdf.js) |

---

## 8. מספור אוטומטי

מספור נוצר ב-DB (Trigger) כשנוצרת רשומה חדשה:

| ישות | פורמט | דוגמה |
|------|--------|-------|
| לקוח | C + 5 ספרות | C00001 |
| פרויקט | P + 6 ספרות | P000001 |
| משימה | M + 6 ספרות | M000001 |
| מוצר | PR + 5 ספרות | PR00001 |
| הצעת מחיר | QT + שנה + 6 ספרות | QT26000001 |
| חשבונית טיוטה | T + שנה + 4 ספרות | T260001 |
| חשבונית סופית | INV + שנה + 4 ספרות | INV260001 |

---

## 9. הדפסה

### ארכיטקטורה

הדפסה עובדת כך: JavaScript בונה HTML מלא → פותח חלון חדש → `window.print()`.

**פונקציות עזר לבניית HTML הדפסה:**
- `_printCompanyHeader(co)` — כותרת עם לוגו שמאל + פרטי חברה ימין
- `_printCustomerBlock(cust)` — בלוק פרטי לקוח
- `_printTotalsBlock(subtotal, vatrate)` — טבלת סיכום (subtotal/vat/total)
- `_printFooter(co)` — חתימה + פרטי תשלום
- `_printBase(title, body, autoPrint)` — template HTML בסיסי עם CSS
- `_printOpenWindow(html)` — פותח חלון ומכניס HTML

### פריסת הדפסה

| צד ימין (RTL) | צד שמאל (RTL) |
|---------------|---------------|
| "בתוקף עד" / "מספר הקצאה" | טבלת סיכום (subtotal/vat/total) |
| — | חתימה |

### כפתור הדפסה — Dropdown

```
🖨️ הדפסה ▾
├── 👁 הצגה       ← פותח ללא הדפסה אוטומטית
├── 🖨️ הדפסה      ← פותח + מדפיס מיד
└── ✉️ שליחה במייל ← placeholder (עתידי)
```

---

## 10. API רשות המסים — מספר הקצאה

### מתי נדרש

חשבוניות מעל **₪5,000** לפני מע"מ חייבות מספר הקצאה (מאז יוני 2026).

### Endpoints

| סביבה | URL |
|-------|-----|
| Sandbox (בדיקות) | `https://api.taxes.gov.il/shaam/tsandbox/Invoices/v2/Approval` |
| ייצור | `https://api.taxes.gov.il/shaam/production/Invoices/v2/Approval` |

### הגדרה במערכת

בנתוני חברה → "API רשות המסים":
- **Bearer Token** — הטוקן שמתקבל מהרשמה ב-`secapp.taxes.gov.il`
- **Sandbox** — סמן V לבדיקות, בטל לייצור

### קוד — `_itaGetAllocationNum(inv, co)`

1. בודק שיש token
2. בוחר URL לפי sandbox/production
3. שולח POST עם: `invoicenumber`, `invoicedate`, `invoiceamount`, `vatnumber`, `vatamount`
4. מחזיר `allocationNumber` מהתשובה

### שלבי הרשמה (טרם בוצע)

1. הירשם ב: `secapp.taxes.gov.il`
2. צור OAuth App → קבל Client ID + Secret
3. קבל Bearer Token
4. הכנס ב"נתוני חברה" → שמור

---

## 11. מיגרציות DB

קבצי SQL שצריך להריץ ב-Supabase Dashboard → SQL Editor:

| קובץ | תוכן | סטטוס |
|------|------|-------|
| `supabase/schema.sql` | כל הטבלאות, RLS, Triggers | ✅ הורץ |
| `supabase/migration_ita_api.sql` | הוסף `ita_token`, `ita_sandbox` לטבלת company | ⚠️ יש להריץ |

---

## 12. מילון מונחים טכניים

| מונח עברי (שלנו) | שם טכני | הסבר |
|-----------------|---------|-------|
| מסד נתונים | Database / DB | איפה המידע מאוחסן |
| טבלה | Table | גיליון של מידע במסד הנתונים |
| עמודה | Column / Field | שדה בטבלה (למשל: שם, טלפון) |
| שורה | Row / Record | רשומה אחת בטבלה |
| מזהה ייחודי | UUID | מחרוזת ייחודית שמזהה כל רשומה |
| מפתח ראשי | Primary Key (PK) | העמודה שמזהה כל שורה (למשל: custid) |
| מפתח זר | Foreign Key (FK) | עמודה שמצביעה לטבלה אחרת |
| רשימת בחירה | Dropdown / Select | שדה שבו בוחרים ערך מרשימה |
| popup קטנה | Toast | הודעה זמנית שמופיעה ומיעלמת |
| חלון קופץ | Modal / Dialog | חלון שמופיע מעל המסך |
| אימות | Authentication | בדיקה שהמשתמש הוא מי שהוא אומר שהוא |
| הרשאות | Permissions / RLS | מי רשאי לקרוא/לכתוב נתונים |
| שמירה אוטומטית | Auto-save | שמירה ללא לחיצת כפתור |
| סנכרון | Sync | עדכון הנתונים בין המסך ל-DB |
| ניווט | Navigation | כפתורי ראשון/קודם/הבא/אחרון |
| Header / Master | טופס ראשי | החלק העליון של מסמך ERP |
| Lines / Son | שורות פירוט | החלק התחתון של מסמך ERP |
| Tab | לשונית | לחיצה שמחליפה תצוגה בתוך מסך |
| RTL | כיוון ימין-לשמאל | `dir="rtl"` — עברית/ערבית |
| API | ממשק תכנותי | דרך לשלוח ולקבל נתונים מ/לשרת חיצוני |
| Bearer Token | טוקן גישה | מחרוזת סודית שמזהה אותנו בAPI |
| OAuth | פרוטוקול הרשאות | שיטת אימות מול APIs חיצוניים |
| Sandbox | סביבת בדיקות | גרסת בדיקה שלא משפיעה על ייצור |
| Trigger | טריגר | פקודה שרצה ב-DB אוטומטית לאחר פעולה |
| RPC | קריאה לפונקציה ב-DB | הרצת לוגיקה ישירות בשרת DB |
| Sequence | סדרה | מנגנון DB שמייצר מספרים עולים |
| RLS | Row Level Security | הגנת DB — כל user רואה רק מה שמותר לו |
| CDN | שרת תוכן | ספרייה חיצונית שנטענת מהאינטרנט |
| Base64 | קידוד תמונה | דרך לאחסן תמונה כמחרוזת טקסט |
| FK Constraint | אילוץ מפתח זר | חוק DB שמונע מחיקה אם יש תלויים |
| Cascade | מחיקה מדורגת | מחיקת אב מוחקת גם את הבנים |
| Restrict | חסימת מחיקה | אי אפשר למחוק אב אם יש בנים |
| State object | אובייקט מצב | משתנה JS שמחזיק מצב נוכחי (רשומה פתוחה, רשימה, ...) |
| Dirty flag | דגל שינוי | true = יש שינויים שלא נשמרו עדיין |
| Debounce | השהיה | המתן X מ"ש לפני שמירה, למנוע שמירות מיותרות |
| Guard | שמירה/חסימה | קוד שבודק תנאי לפני ביצוע פעולה |

---

*עודכן לאחרונה: 2026-04-19*
