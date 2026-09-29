// devices/{deviceId} — firmware-owned telemetry with two console-owned
// pairing fields. The split exists so the console and the helmet can never
// overwrite each other; these tests are what enforces it.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import {
  asAnonymous, asDispatcher, asHelmetService, asSuperAdmin, asViewer, newTestEnv, reset,
} from './helpers.js';

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'devices', 'NR-H1-001'), {
      alcohol_level: 0.01, ax: 0, ay: 0, az: 9.8, latitude: 14.6, longitude: 121.0,
    });
  });
});

describe('devices/', () => {
  it('is readable by any operator and by nobody else', async () => {
    await assertSucceeds(getDoc(doc(asViewer(env), 'devices', 'NR-H1-001')));
    await assertFails(getDoc(doc(asAnonymous(env), 'devices', 'NR-H1-001')));
    await assertFails(getDoc(doc(asHelmetService(env), 'devices', 'NR-H1-001')));
  });

  it('lets the helmet service write readings', async () => {
    await assertSucceeds(
      updateDoc(doc(asHelmetService(env), 'devices', 'NR-H1-001'), {
        alcohol_level: 0.07, vector_magnitude: 22.4,
      }),
    );
    await assertSucceeds(
      setDoc(doc(asHelmetService(env), 'devices', 'NR-H1-002'), { alcohol_level: 0 }),
    );
  });

  it('lets a Super Admin create a device for a helmet that never reported', async () => {
    await assertSucceeds(
      setDoc(doc(asSuperAdmin(env), 'devices', 'NR-H1-003'), {
        assigned_rider_id: 'R-001', paired_at: serverTimestamp(),
      }),
    );
  });

  it('lets a Super Admin change only the pairing on an existing device', async () => {
    const db = asSuperAdmin(env);
    await assertSucceeds(
      updateDoc(doc(db, 'devices', 'NR-H1-001'), {
        assigned_rider_id: 'R-001', paired_at: serverTimestamp(),
      }),
    );
    await assertFails(updateDoc(doc(db, 'devices', 'NR-H1-001'), { alcohol_level: 0 }));
    await assertFails(
      updateDoc(doc(db, 'devices', 'NR-H1-001'), { assigned_rider_id: 'R-001', ax: 1 }),
    );
  });

  it('refuses writes by a dispatcher or a viewer', async () => {
    await assertFails(setDoc(doc(asDispatcher(env), 'devices', 'NR-H1-004'), { ax: 0 }));
    await assertFails(
      updateDoc(doc(asDispatcher(env), 'devices', 'NR-H1-001'), { assigned_rider_id: 'R-001' }),
    );
    await assertFails(
      updateDoc(doc(asViewer(env), 'devices', 'NR-H1-001'), { assigned_rider_id: 'R-001' }),
    );
  });

  it('refuses deletion by anyone', async () => {
    await assertFails(deleteDoc(doc(asSuperAdmin(env), 'devices', 'NR-H1-001')));
    await assertFails(deleteDoc(doc(asHelmetService(env), 'devices', 'NR-H1-001')));
  });
});
