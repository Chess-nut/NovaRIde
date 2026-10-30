// Families, membership, invitations and family-scoped rider data access.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs,
  query, serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';
import {
  asGuardian, asOtherRider, asRider, newTestEnv, OTHER_UID, reset,
  RIDER_EMAIL, RIDER_UID,
} from './helpers.js';

const ACTIVE_GUARDIAN = 'uid-family-guardian-active';
const ACTIVE_GUARDIAN_EMAIL = 'active.guardian@example.test';
const PERMISSIONS = {
  liveLocation: true,
  emergencyAlerts: true,
  tripStatus: true,
  helmetStatus: true,
  incidentHistory: true,
};
const NO_PERMISSIONS = {
  liveLocation: false,
  emergencyAlerts: false,
  tripStatus: false,
  helmetStatus: false,
  incidentHistory: false,
};
const inviteCode = 'family-invite-guardian-0001';

const asActiveGuardian = (env) =>
  env.authenticatedContext(ACTIVE_GUARDIAN, { email: ACTIVE_GUARDIAN_EMAIL }).firestore();
const asWrongEmailGuardian = (env) =>
  env.authenticatedContext('uid-mobile-guardian', { email: 'wrong@example.test' }).firestore();

const member = (uid, role, status = 'active', permissions = PERMISSIONS) => ({
  uid,
  role,
  status,
  permissions,
  displayName: role === 'rider' ? 'Rider One' : 'Family Guardian',
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
});

const pendingInvite = (familyId = RIDER_UID, invitedEmail = 'guardian@example.test') => ({
  familyId,
  invitedBy: familyId,
  invitedEmail,
  status: 'pending',
  createdAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
});

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'users', RIDER_UID), {
      role: 'rider', familyId: RIDER_UID, email: RIDER_EMAIL,
    });
    await setDoc(doc(db, 'users', OTHER_UID), {
      role: 'rider', familyId: OTHER_UID, email: 'other@example.test',
    });
    await setDoc(doc(db, 'users', 'uid-mobile-guardian'), {
      role: 'guardian', email: 'guardian@example.test',
    });
    await setDoc(doc(db, 'users', ACTIVE_GUARDIAN), {
      role: 'guardian', familyId: RIDER_UID, email: ACTIVE_GUARDIAN_EMAIL,
    });
    await setDoc(doc(db, 'families', RIDER_UID), {
      ownerUid: RIDER_UID, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'families', RIDER_UID, 'members', RIDER_UID),
      member(RIDER_UID, 'rider'));
    await setDoc(doc(db, 'families', RIDER_UID, 'members', ACTIVE_GUARDIAN),
      member(ACTIVE_GUARDIAN, 'guardian'));
    await setDoc(doc(db, 'families', OTHER_UID), {
      ownerUid: OTHER_UID, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'families', OTHER_UID, 'members', OTHER_UID),
      member(OTHER_UID, 'rider'));

    await setDoc(doc(db, 'riders', 'R-family'), {
      fullName: 'Rider One', authUid: RIDER_UID, helmetId: 'NR-H1-FAMILY',
    });
    await setDoc(doc(db, 'riders', 'R-other-family'), {
      fullName: 'Other Rider', authUid: OTHER_UID, helmetId: 'NR-H1-OTHER',
    });
    await setDoc(doc(db, 'devices', 'NR-H1-FAMILY'), {
      assigned_rider_id: 'R-family', latitude: 14.6, longitude: 121.0,
    });
    await setDoc(doc(db, 'alerts', 'A-family'), {
      riderId: 'R-family', type: 'sos', status: 'open',
      timestamp: Timestamp.now(), lat: 14.6, lng: 121.0,
    });
    await setDoc(doc(db, 'alerts', 'A-other-family'), {
      riderId: 'R-other-family', type: 'sos', status: 'open',
      timestamp: Timestamp.now(), lat: 14.6, lng: 121.0,
    });
    await setDoc(doc(db, 'alerts', 'A-family', 'history', 'H-1'), {
      toStatus: 'acknowledged', actorName: 'Dispatcher', at: Timestamp.now(),
    });
    await setDoc(doc(db, 'alerts', 'A-other-family', 'history', 'H-2'), {
      toStatus: 'acknowledged', actorName: 'Dispatcher', at: Timestamp.now(),
    });
    await setDoc(doc(db, 'familyInvites', inviteCode),
      pendingInvite(RIDER_UID, 'guardian@example.test'));
    await setDoc(doc(db, 'familyInvites', 'family-invite-expired-0001'), {
      ...pendingInvite(RIDER_UID, 'guardian@example.test'),
      expiresAt: Timestamp.fromMillis(Date.now() - 60 * 1000),
    });
  });
});

const acceptInvite = async (
  db, code = inviteCode, permissions = NO_PERMISSIONS, extraMemberFields = {},
) => {
  const batch = writeBatch(db);
  batch.update(doc(db, 'users', 'uid-mobile-guardian'), {
    familyId: RIDER_UID,
    familyInviteCode: code,
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'familyInvites', code), {
    status: 'accepted',
    acceptedBy: 'uid-mobile-guardian',
    acceptedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'families', RIDER_UID, 'members', 'uid-mobile-guardian'), {
    ...member('uid-mobile-guardian', 'guardian', 'active', permissions),
    ...extraMemberFields,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await batch.commit();
};

describe('family schema and private reads', () => {
  it('allows active members to get the family and list its members only', async () => {
    await assertSucceeds(getDoc(doc(asRider(env), 'families', RIDER_UID)));
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'families', RIDER_UID)));
    await assertSucceeds(getDoc(doc(
      asActiveGuardian(env), 'families', RIDER_UID, 'members', RIDER_UID,
    )));
    const members = await assertSucceeds(getDocs(collection(
      asActiveGuardian(env), 'families', RIDER_UID, 'members',
    )));
    if (members.size !== 2) throw new Error(`expected two members, got ${members.size}`);
    const guardianData = members.docs.find((entry) => entry.id === ACTIVE_GUARDIAN).data();
    if (guardianData.displayName !== 'Family Guardian'
      || guardianData.role !== 'guardian'
      || guardianData.status !== 'active'
      || 'email' in guardianData || 'phone' in guardianData
      || 'familyInviteCode' in guardianData) {
      throw new Error('member data must remain a safe family projection');
    }
    await assertFails(getDoc(doc(asOtherRider(env), 'families', RIDER_UID)));
    await assertFails(getDocs(collection(asRider(env), 'families')));
    await assertFails(getDocs(collection(asOtherRider(env), 'families', RIDER_UID, 'members')));
  });

  it('denies a revoked member all family reads', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), { status: 'revoked' });
    });
    await assertFails(getDoc(doc(asActiveGuardian(env), 'families', RIDER_UID)));
    await assertFails(getDoc(doc(
      asActiveGuardian(env), 'families', RIDER_UID, 'members', RIDER_UID,
    )));
    await assertFails(getDoc(doc(asActiveGuardian(env), 'riders', 'R-family')));
    await assertFails(getDoc(doc(asActiveGuardian(env), 'devices', 'NR-H1-FAMILY')));
    await assertFails(getDoc(doc(asActiveGuardian(env), 'alerts', 'A-family')));
    await assertFails(getDoc(doc(
      asActiveGuardian(env), 'alerts', 'A-family', 'history', 'H-1',
    )));
  });

  it('refuses client family edits, deletes, and owner-uid impersonation', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'families', RIDER_UID), {
      ownerUid: 'uid-mobile-guardian', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asRider(env), 'families', RIDER_UID), {
      updatedAt: serverTimestamp(),
    }));
  });
});

describe('family reads of linked roster and live data', () => {
  it('allows active members to read the linked rider, not another family', async () => {
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'riders', 'R-family')));
    await assertSucceeds(getDocs(query(
      collection(asActiveGuardian(env), 'riders'), where('authUid', '==', RIDER_UID),
    )));
    await assertFails(getDoc(doc(asActiveGuardian(env), 'riders', 'R-other-family')));
    await assertFails(getDoc(doc(asOtherRider(env), 'riders', 'R-family')));
  });

  it('requires liveLocation, tripStatus and helmetStatus for rider and device docs', async () => {
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'devices', 'NR-H1-FAMILY')));
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'riders', 'R-family')));
    await assertSucceeds(getDocs(query(
      collection(asActiveGuardian(env), 'devices'),
      where('assigned_rider_id', '==', 'R-family'),
    )));
    for (const permission of ['liveLocation', 'tripStatus', 'helmetStatus']) {
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), {
          permissions: { ...PERMISSIONS, [permission]: false },
        });
      });
      await assertFails(getDoc(doc(asActiveGuardian(env), 'devices', 'NR-H1-FAMILY')));
      await assertFails(getDoc(doc(asActiveGuardian(env), 'riders', 'R-family')));
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), { permissions: PERMISSIONS });
      });
    }
    await assertFails(getDoc(doc(asOtherRider(env), 'devices', 'NR-H1-FAMILY')));
  });

  it('requires emergencyAlerts and liveLocation for alerts', async () => {
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'alerts', 'A-family')));
    await assertSucceeds(getDocs(query(
      collection(asActiveGuardian(env), 'alerts'), where('riderId', '==', 'R-family'),
    )));
    await assertFails(getDocs(query(
      collection(asActiveGuardian(env), 'alerts'),
      where('riderId', '==', 'R-other-family'),
    )));
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), {
        permissions: {
          ...PERMISSIONS,
          emergencyAlerts: false,
          tripStatus: false,
          helmetStatus: false,
        },
      });
    });
    await assertSucceeds(getDoc(doc(asActiveGuardian(env), 'alerts', 'A-family')));
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), { permissions: PERMISSIONS });
    });
    for (const permission of ['emergencyAlerts', 'liveLocation']) {
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), {
          permissions: { ...PERMISSIONS, [permission]: false },
        });
      });
      await assertFails(getDoc(doc(asActiveGuardian(env), 'alerts', 'A-family')));
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), { permissions: PERMISSIONS });
      });
    }
    await assertFails(getDoc(doc(asActiveGuardian(env), 'alerts', 'A-other-family')));
  });

  it('requires incidentHistory and liveLocation for alert history', async () => {
    const db = asActiveGuardian(env);
    await assertSucceeds(getDoc(doc(db, 'alerts', 'A-family', 'history', 'H-1')));
    await assertFails(getDoc(doc(db, 'alerts', 'A-other-family', 'history', 'H-2')));
    await assertSucceeds(getDocs(collection(db, 'alerts', 'A-family', 'history')));
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), {
        permissions: {
          ...PERMISSIONS,
          emergencyAlerts: false,
          tripStatus: false,
          helmetStatus: false,
        },
      });
    });
    await assertSucceeds(getDoc(doc(db, 'alerts', 'A-family', 'history', 'H-1')));
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), { permissions: PERMISSIONS });
    });
    for (const permission of ['incidentHistory', 'liveLocation']) {
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), {
          permissions: { ...PERMISSIONS, [permission]: false },
        });
      });
      await assertFails(getDoc(doc(db, 'alerts', 'A-family', 'history', 'H-1')));
      await assertFails(getDocs(collection(db, 'alerts', 'A-family', 'history')));
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
          'members', ACTIVE_GUARDIAN), { permissions: PERMISSIONS });
      });
    }
  });

  it('allows no guardian writes to riders, devices, or alerts', async () => {
    const db = asActiveGuardian(env);
    await assertFails(updateDoc(doc(db, 'riders', 'R-family'), { status: 'idle' }));
    await assertFails(updateDoc(doc(db, 'devices', 'NR-H1-FAMILY'), { latitude: 0 }));
    await assertFails(updateDoc(doc(db, 'alerts', 'A-family'), { status: 'resolved' }));
    await assertFails(setDoc(doc(db, 'riders', 'R-family-NEW'), {
      fullName: 'Blocked', authUid: ACTIVE_GUARDIAN,
    }));
    await assertFails(setDoc(doc(db, 'devices', 'NR-H1-NEW'), { latitude: 0 }));
    await assertFails(setDoc(doc(db, 'alerts', 'A-new'), { riderId: 'R-family' }));
  });
});

describe('owner permissions and membership escalation', () => {
  it('lets only the rider owner change another guardian permissions', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      permissions: { ...PERMISSIONS, helmetStatus: false },
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asActiveGuardian(env), 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      permissions: PERMISSIONS,
      updatedAt: serverTimestamp(),
    }));
  });

  it('lets the owner revoke a guardian and a guardian revoke themself', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      status: 'revoked', updatedAt: serverTimestamp(),
    }));
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'families', RIDER_UID,
        'members', ACTIVE_GUARDIAN), { status: 'active' });
    });
    const db = asActiveGuardian(env);
    const batch = writeBatch(db);
    batch.update(doc(db, 'families', RIDER_UID, 'members', ACTIVE_GUARDIAN), {
      status: 'revoked', updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'users', ACTIVE_GUARDIAN), {
      familyId: deleteField(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  it('refuses guardian role changes, permission escalation and direct membership', async () => {
    const db = asActiveGuardian(env);
    await assertFails(updateDoc(doc(db, 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      role: 'rider', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      permissions: { ...PERMISSIONS, incidentHistory: false },
      status: 'revoked', updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(db, 'families', RIDER_UID,
      'members', 'uid-uninvited'), member('uid-uninvited', 'guardian')));
    await assertFails(updateDoc(doc(db, 'users', 'uid-mobile-guardian'), {
      role: 'rider', familyId: RIDER_UID, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asActiveGuardian(env), 'users', ACTIVE_GUARDIAN), {
      familyId: OTHER_UID, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'users', 'uid-mobile-guardian'), {
      familyId: null, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'users', 'uid-mobile-guardian'), {
      familyId: RIDER_UID, updatedAt: serverTimestamp(),
    }));
  });

  it('allows a first-time rider to atomically add its owner family', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users', RIDER_UID), {
        role: 'rider', email: RIDER_EMAIL,
      });
      await setDoc(doc(db, 'riderProfiles', RIDER_UID), {
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      await deleteDoc(doc(db, 'families', RIDER_UID));
      await deleteDoc(doc(db, 'families', RIDER_UID, 'members', RIDER_UID));
    });
    const db = asRider(env);
    const batch = writeBatch(db);
    batch.update(doc(db, 'users', RIDER_UID), {
      familyId: RIDER_UID, updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'families', RIDER_UID), {
      ownerUid: RIDER_UID, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'families', RIDER_UID, 'members', RIDER_UID), {
      ...member(RIDER_UID, 'rider'), createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  it('denies first-time rider familyId migration without matching family/member', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users', RIDER_UID), {
        role: 'rider', email: RIDER_EMAIL,
      });
      await setDoc(doc(db, 'riderProfiles', RIDER_UID), {
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      await deleteDoc(doc(db, 'families', RIDER_UID));
      await deleteDoc(doc(db, 'families', RIDER_UID, 'members', RIDER_UID));
    });
    await assertFails(updateDoc(doc(asRider(env), 'users', RIDER_UID), {
      familyId: RIDER_UID, updatedAt: serverTimestamp(),
    }));
  });

  it('allows a revoked guardian to unlink the old family, but not while active', async () => {
    await assertFails(updateDoc(doc(asActiveGuardian(env), 'users', ACTIVE_GUARDIAN), {
      familyId: deleteField(), updatedAt: serverTimestamp(),
    }));
    const db = asActiveGuardian(env);
    await assertFails(updateDoc(doc(db, 'families', RIDER_UID,
      'members', ACTIVE_GUARDIAN), {
      status: 'revoked', updatedAt: serverTimestamp(),
    }));
    const batch = writeBatch(db);
    batch.update(doc(db, 'families', RIDER_UID, 'members', ACTIVE_GUARDIAN), {
      status: 'revoked', updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'users', ACTIVE_GUARDIAN), {
      familyId: deleteField(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
    await assertFails(getDoc(doc(db, 'families', RIDER_UID)));
  });
});

describe('short-lived, email-bound family invites', () => {
  it('allows only the owner to create a pending short-lived invite', async () => {
    const invite = {
      familyId: RIDER_UID,
      invitedBy: RIDER_UID,
      invitedEmail: 'guardian@example.test',
      status: 'pending',
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    };
    await assertSucceeds(setDoc(doc(asRider(env), 'familyInvites', 'invite-code-new-000001'),
      invite));
    const unboundInvite = { ...invite };
    delete unboundInvite.invitedEmail;
    await assertSucceeds(setDoc(
      doc(asRider(env), 'familyInvites', 'invite-code-unbound-000001'),
      unboundInvite,
    ));
    await assertFails(setDoc(doc(asActiveGuardian(env), 'familyInvites', 'invite-code-new-000002'),
      invite));
    await assertFails(setDoc(doc(asRider(env), 'familyInvites', 'short'),
      invite));
    await assertFails(setDoc(doc(asRider(env), 'familyInvites', 'invite-code-too-long-000003'), {
      ...invite, expiresAt: Timestamp.fromMillis(Date.now() + 25 * 60 * 60 * 1000),
    }));
    await assertFails(setDoc(doc(asRider(env), 'familyInvites', 'invite-code-client-time-0001'), {
      ...invite, createdAt: Timestamp.now(),
    }));
  });

  it('allows pending, unexpired gets only for authenticated matching email', async () => {
    await assertSucceeds(getDoc(doc(asGuardian(env), 'familyInvites', inviteCode)));
    await assertFails(getDoc(doc(asWrongEmailGuardian(env), 'familyInvites', inviteCode)));
    await assertFails(getDoc(doc(asOtherRider(env), 'familyInvites', inviteCode)));
    await assertFails(getDoc(doc(asGuardian(env), 'familyInvites', 'family-invite-expired-0001')));
    await assertFails(getDocs(collection(asGuardian(env), 'familyInvites')));
  });

  it('accepts once in a transaction and binds user and member to that invite', async () => {
    await assertFails(acceptInvite(asGuardian(env), inviteCode, PERMISSIONS));
    await assertFails(acceptInvite(asGuardian(env), inviteCode, NO_PERMISSIONS, {
      email: 'guardian@example.test',
      phone: '+639171234567',
    }));
    await assertSucceeds(acceptInvite(asGuardian(env)));
    await assertSucceeds(getDoc(doc(asGuardian(env), 'families', RIDER_UID)));
    await assertFails(getDoc(doc(asGuardian(env), 'riders', 'R-family')));
    await assertFails(getDoc(doc(asGuardian(env), 'devices', 'NR-H1-FAMILY')));
    await assertFails(getDoc(doc(asGuardian(env), 'alerts', 'A-family')));
    await assertSucceeds(updateDoc(doc(asRider(env), 'families', RIDER_UID,
      'members', 'uid-mobile-guardian'), {
      permissions: PERMISSIONS, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(asGuardian(env), 'riders', 'R-family')));
    await assertSucceeds(getDoc(doc(asGuardian(env), 'devices', 'NR-H1-FAMILY')));
    await assertSucceeds(getDoc(doc(asGuardian(env), 'alerts', 'A-family')));
    await assertFails(getDoc(doc(asGuardian(env), 'familyInvites', inviteCode)));
    await assertFails(acceptInvite(asGuardian(env)));
  });

  it('allows a revoked guardian to rejoin only through a new accepted invite', async () => {
    await assertSucceeds(acceptInvite(asGuardian(env)));
    const guardianDb = asGuardian(env);
    const originalMember = await getDoc(doc(
      guardianDb, 'families', RIDER_UID, 'members', 'uid-mobile-guardian',
    ));
    await assertSucceeds(updateDoc(doc(asRider(env), 'families', RIDER_UID,
      'members', 'uid-mobile-guardian'), {
      permissions: PERMISSIONS, updatedAt: serverTimestamp(),
    }));
    const leave = writeBatch(guardianDb);
    leave.update(doc(guardianDb, 'families', RIDER_UID, 'members', 'uid-mobile-guardian'), {
      status: 'revoked', updatedAt: serverTimestamp(),
    });
    leave.update(doc(guardianDb, 'users', 'uid-mobile-guardian'), {
      familyId: deleteField(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(leave.commit());

    const nextCode = 'family-invite-guardian-0002';
    await assertSucceeds(setDoc(doc(asRider(env), 'familyInvites', nextCode), {
      familyId: RIDER_UID,
      invitedBy: RIDER_UID,
      invitedEmail: 'guardian@example.test',
      status: 'pending',
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    }));
    const escalation = writeBatch(guardianDb);
    escalation.update(doc(guardianDb, 'users', 'uid-mobile-guardian'), {
      familyId: RIDER_UID, familyInviteCode: nextCode, updatedAt: serverTimestamp(),
    });
    escalation.update(doc(guardianDb, 'familyInvites', nextCode), {
      status: 'accepted',
      acceptedBy: 'uid-mobile-guardian',
      acceptedAt: serverTimestamp(),
    });
    escalation.update(doc(guardianDb, 'families', RIDER_UID, 'members', 'uid-mobile-guardian'), {
      role: 'rider',
      status: 'active',
      updatedAt: serverTimestamp(),
    });
    await assertFails(escalation.commit());

    const rejoin = writeBatch(guardianDb);
    rejoin.update(doc(guardianDb, 'users', 'uid-mobile-guardian'), {
      familyId: RIDER_UID, familyInviteCode: nextCode, updatedAt: serverTimestamp(),
    });
    rejoin.update(doc(guardianDb, 'familyInvites', nextCode), {
      status: 'accepted',
      acceptedBy: 'uid-mobile-guardian',
      acceptedAt: serverTimestamp(),
    });
    rejoin.update(doc(guardianDb, 'families', RIDER_UID, 'members', 'uid-mobile-guardian'), {
      role: 'guardian',
      displayName: 'Guardian One Updated',
      permissions: NO_PERMISSIONS,
      status: 'active',
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(rejoin.commit());
    const rejoinedMember = await getDoc(doc(
      guardianDb, 'families', RIDER_UID, 'members', 'uid-mobile-guardian',
    ));
    if (!rejoinedMember.data().createdAt.isEqual(originalMember.data().createdAt)) {
      throw new Error('rejoining must preserve the member createdAt timestamp');
    }
  });

  it('denies email mismatch, expired acceptance, replay and direct guardian linking', async () => {
    await assertFails(acceptInvite(asWrongEmailGuardian(env)));
    await assertFails(acceptInvite(asGuardian(env), 'family-invite-expired-0001'));
    await assertFails(updateDoc(doc(asGuardian(env), 'familyInvites', inviteCode), {
      status: 'accepted',
      acceptedBy: 'uid-mobile-guardian',
      acceptedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asGuardian(env), 'users', 'uid-mobile-guardian'), {
      familyId: RIDER_UID, updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(asGuardian(env), 'families', RIDER_UID,
      'members', 'uid-mobile-guardian'), {
      ...member('uid-mobile-guardian', 'guardian'),
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });
});
