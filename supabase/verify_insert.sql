-- Ekleme kontrolü
SELECT id, company_name, coupon_name, discount_rate, color, created_at
FROM public.discounts
WHERE company_name = 'atozcan1.6';

-- Tüm discounts kayıtları
SELECT id, company_name, coupon_name, discount_rate, color
FROM public.discounts
ORDER BY created_at DESC;