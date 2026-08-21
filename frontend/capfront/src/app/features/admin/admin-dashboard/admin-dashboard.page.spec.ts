// File purpose: Covers Angular tests for admin dashboard page spec behavior.
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { ModerationService } from '../../../core/services/moderation.service';
import { RewardsService } from '../../../core/services/rewards.service';
import { AdminDashboardPageComponent } from './admin-dashboard.page';

describe('AdminDashboardPageComponent', () => {
  let fixture: ComponentFixture<AdminDashboardPageComponent>;
  let component: AdminDashboardPageComponent;
  let moderationService: jasmine.SpyObj<ModerationService>;
  let rewardsService: jasmine.SpyObj<RewardsService>;

  beforeEach(async () => {
    moderationService = jasmine.createSpyObj<ModerationService>('ModerationService', [
      'listSubmissions',
      'countSubmissions',
    ]);
    rewardsService = jasmine.createSpyObj<RewardsService>('RewardsService', ['getLeaderboard']);

    moderationService.listSubmissions.and.callFake((query = {}) => {
      if (query.status === 'PENDING' && query.sort === 'createdAt,desc') {
        return of({
          items: [
            {
              id: 11,
              type: 'PRODUCT',
              status: 'PENDING',
              payload: {},
              notes: null,
              reviewReason: null,
              submittedByUserId: 1,
              submittedByEmail: 'user@capstone.local',
              createdAt: '2026-04-17T10:00:00Z',
              updatedAt: '2026-04-17T10:00:00Z',
            },
          ],
          totalElements: 4,
          page: 0,
          size: 6,
          totalPages: 1,
        });
      }
      if (query.status === 'PENDING' && query.sort === 'createdAt,asc') {
        return of({
          items: [
            {
              id: 7,
              type: 'PRICE',
              status: 'PENDING',
              payload: {},
              notes: null,
              reviewReason: null,
              submittedByUserId: 2,
              submittedByEmail: 'older@capstone.local',
              createdAt: '2026-04-10T09:00:00Z',
              updatedAt: '2026-04-10T09:00:00Z',
            },
          ],
          totalElements: 4,
          page: 0,
          size: 1,
          totalPages: 4,
        });
      }
      return of({
        items: [],
        totalElements: 0,
        page: 0,
        size: 1,
        totalPages: 0,
      });
    });

    moderationService.countSubmissions.and.callFake((status) => {
      if (status === 'APPROVED') {
        return of(9);
      }
      if (status === 'REJECTED') {
        return of(2);
      }
      return of(0);
    });

    rewardsService.getLeaderboard.and.returnValue(
      of({
        window: 'ALL_TIME',
        limit: 5,
        entries: [
          {
            rank: 1,
            userId: 1,
            email: 'leader@capstone.local',
            score: 35,
            approvedCount: 6,
            rejectedCount: 1,
            lastEventAt: '2026-04-17T10:00:00Z',
          },
        ],
      }),
    );

    await TestBed.configureTestingModule({
      imports: [AdminDashboardPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        { provide: ModerationService, useValue: moderationService },
        { provide: RewardsService, useValue: rewardsService },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminDashboardPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads moderation summary and leaderboard', () => {
    expect(moderationService.listSubmissions).toHaveBeenCalled();
    expect(moderationService.countSubmissions).toHaveBeenCalledWith('APPROVED');
    expect(moderationService.countSubmissions).toHaveBeenCalledWith('REJECTED');
    expect(rewardsService.getLeaderboard).toHaveBeenCalledWith('ALL_TIME', 5);
    expect(component.summary().pending).toBe(4);
    expect(component.summary().approved).toBe(9);
    expect(component.summary().rejected).toBe(2);
    expect(component.topContributors().length).toBe(1);
  });
});
