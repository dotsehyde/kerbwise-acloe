# Brief: a courier app for Kerbwise

This is a forwarded email thread. Kerbwise and everyone in it are invented for this exercise.

**About Kerbwise.** A London startup, two years old, eleven people. Independent shops (bakeries, florists, delis, gift shops) use Kerbwise to take orders, send them out with same-day couriers and talk to their customers. You are an engineer from Acloe who has just joined their team.

---

**From:** Hannah Whitlock, founder of Kerbwise
**To:** you

Hi, welcome aboard. Our couriers each do about 40 drops a day for the shops. Today they work from a WhatsApp list and a notebook. Some customers pay the courier at the door, and we lose money every week because couriers forget to write down what they collected, or round it.

I would like an app for the couriers. What I picture:

- They open it and see today's deliveries, nothing else. They tap one to see the address and to call the customer.
- When they hand over the parcel they tap Delivered. If the customer pays cash at the door, they enter the cash they collected. I want to catch mistakes, so the app should not let a courier record the wrong amount.
- It must work in the dead zones. Couriers lose signal in basement flats, lifts and parts of the Overground for 10 to 20 minutes at a time, and they must still be able to finish a delivery and have it go through later.
- It must look like us. I love how Instagram looks: bold and clean like that.
- A map with the route would be great, and a notification when a new delivery is assigned.
- I would like it on my iPhone too, so I can watch.
- Couriers sometimes tap buttons twice. That must not cause trouble.

Thanks,
Hannah

---

**From:** Marcus Reid, operations (he runs the couriers)
**To:** you, Hannah

Some things from the couriers. Most of them have older Android phones with 2 or 3 GB of memory, small screens and often a cracked one. They ride in rain and bright daylight and wear gloves in winter. Several of the older couriers use the large text setting. Most are on pay-as-you-go data, so please do not use a lot of it. A few phones have the wrong date and time and nobody has fixed them.

Another thing: when the customer is not home, what do they press? Today they just call the office.

---

**From:** Tomasz Zielinski, developer (he built the first version of the platform)
**To:** you, Hannah

Quick notes from me. The couriers' own numbers are theirs, but customers' numbers are personal data, and couriers lose phones or leave, so please be careful about what stays on a phone. We give couriers the app by sending them the APK for now; we are not on the Play Store. The API is the one described in `courier-api-notes.md`. Most orders come from the shops' websites, and some come in from Instagram through another tool. I am travelling this week and will not see replies until Friday.

---

## What you are building

A mobile app for the couriers, in Flutter or React Native: use the one you know best and say which in your README. The steps are on the challenge page. Use the mock API in `courier-api-notes.md` and `courier-server.js` (run it with Node; it needs no packages).
