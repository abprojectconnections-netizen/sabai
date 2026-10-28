import { BellRing, Briefcase, CreditCard, FileText, Hotel, Landmark, Plane, Settings, Sparkles, Ticket, Users, UtensilsCrossed } from 'lucide-react';

export const TYPE_ICON = { hotel: Hotel, restaurant: UtensilsCrossed, flight: Plane, attraction: Landmark, trip: Sparkles };

export const TYPE_GRADIENT = {
  hotel: 'linear-gradient(135deg,#1C5C57,#0B2422)',
  restaurant: 'linear-gradient(135deg,#B5651D,#7A4B22)',
  flight: 'linear-gradient(135deg,#123C69,#3E92CC)',
  attraction: 'linear-gradient(135deg,#3B2352,#A768C9)',
  trip: 'linear-gradient(135deg,#10403D,#E3A23C)',
};

export const TYPE_LABEL = { hotel: 'ที่พัก', restaurant: 'อาหาร', flight: 'เที่ยวบิน', attraction: 'สถานที่เที่ยว', trip: 'ทริป' };

export const NOTIF_ICON = { booking: FileText, payment: CreditCard, promotion: Ticket, trip: Briefcase, system: Settings, community: Users, reminder: BellRing };
