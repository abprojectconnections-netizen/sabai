
export const FONT_CSS = `
@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
:root{
  --ink:#16241F; --ink-soft:#5C6A64; --paper:#FAFAF8; --surface:#FFFFFF;
  --pine:#10403D; --pine-light:#1C5C57; --pine-pale:#E4EDEA;
  --amber:#E3A23C; --amber-soft:#F6E4C1; --border:#E4E1D8; --danger:#C0483A;
  --amber-ink:#8A5A17; --on-amber:#4A2E06; --on-amber-solid:#4A2E06; --danger-soft:#F6DCD6; --muted-bg:#EDEAE2; --disabled:#B9C4C1;
}
.theme-dark{
  --ink:#EDF1EE; --ink-soft:#9FB2AB; --paper:#0E1614; --surface:#17231F;
  --pine:#2F8A7F; --pine-light:#3A9D91; --pine-pale:#1D312C;
  --amber:#E3A23C; --amber-soft:#3A2E17; --border:#2B3B36; --danger:#E0705F;
  --amber-ink:#F0B95C; --on-amber:#F6E4C1; --on-amber-solid:#4A2E06; --danger-soft:#3C201C; --muted-bg:#23312D; --disabled:#3B4B46;
  color-scheme:dark;
}
.font-display{ font-family:'Fraunces', serif; }
@keyframes spin-slow{ to{ transform:rotate(360deg); } }
@keyframes fade-up{ from{opacity:0; transform:translateY(8px);} to{opacity:1; transform:translateY(0);} }
.fade-up{ animation: fade-up .35s ease both; }
.scrollbar-hide::-webkit-scrollbar{ display:none; }
.scrollbar-hide{ -ms-overflow-style:none; scrollbar-width:none; }
`;
