// File purpose: Covers Angular tests for admin rewards page spec behavior.
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of } from 'rxjs';
import { AuthSessionService } from '../../../core/services/auth-session.service';
import { RewardsService } from '../../../core/services/rewards.service';
import { AdminRewardsPageComponent } from './admin-rewards.page';

describe('AdminRewardsPageComponent', () => {
  let fixture: ComponentFixture<AdminRewardsPageComponent>;
  let component: AdminRewardsPageComponent;
  let rewardsService: jasmine.SpyObj<RewardsService>;

  beforeEach(async () => {
    rewardsService = jasmine.createSpyObj<RewardsService>('RewardsService', [
      'getLeaderboard',
      'getMe',
      'recompute',
    ]);
    rewardsService.getLeaderboard.and.callFake((window) => {
      const resolvedWindow = window ?? 'ALL_TIME';
      return of({
        window: resolvedWindow,
        limit: 50,
        entries:
          resolvedWindow === '30D'
            ? [
                {
                  rank: 1,
                  userId: 2,
                  email: 'recent-high@capstone.local',
                  score: 12,
                  approvedCount: 2,
                  rejectedCount: 0,
                  lastEventAt: '2026-05-07T10:00:00Z',
                },
                {
                  rank: 2,
                  userId: 3,
                  email: 'recent-low@capstone.local',
                  score: 6,
                  approvedCount: 1,
                  rejectedCount: 0,
                  lastEventAt: '2026-05-06T10:00:00Z',
                },
              ]
            : [
                {
                  rank: 1,
                  userId: 1,
                  email: 'leader@capstone.local',
                  score: 42,
                  approvedCount: 7,
                  rejectedCount: 1,
                  lastEventAt: '2026-04-17T10:00:00Z',
                },
              ],
      });
    });
    rewardsService.getMe.and.returnValue(
      of({
        stats: {
          userId: 1,
          email: 'leader@capstone.local',
          approvedProductCount: 2,
          approvedPriceCount: 3,
          approvedNutritionCount: 2,
          approvedTotalCount: 7,
          rejectedCount: 1,
          score: 42,
          lastEventAt: '2026-04-17T10:00:00Z',
        },
        recentEvents: [],
      }),
    );
    rewardsService.recompute.and.returnValue(
      of({
        rebuiltStats: 3,
        rebuiltEvents: 18,
      }),
    );

    await TestBed.configureTestingModule({
      imports: [AdminRewardsPageComponent],
      providers: [
        provideNoopAnimations(),
        { provide: RewardsService, useValue: rewardsService },
        {
          provide: AuthSessionService,
          useValue: { isAdmin: () => true },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminRewardsPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads leaderboard and my stats', () => {
    expect(rewardsService.getLeaderboard).toHaveBeenCalledWith('ALL_TIME', 50);
    expect(rewardsService.getMe).toHaveBeenCalled();
    expect(component.leaderboard().length).toBe(1);
    expect(component.myStats()?.score).toBe(42);
  });

  it('triggers recompute and refreshes data', () => {
    component.onRecompute();
    expect(rewardsService.recompute).toHaveBeenCalled();
  });

  it('reloads the leaderboard when the last 30 days window is selected', () => {
    component.windowControl.setValue('30D');
    fixture.detectChanges();

    expect(rewardsService.getLeaderboard).toHaveBeenCalledWith('30D', 50);
    expect(component.leaderboard().map((entry) => entry.email)).toEqual([
      'recent-high@capstone.local',
      'recent-low@capstone.local',
    ]);
    expect(fixture.nativeElement.textContent).toContain('recent-high@capstone.local');
    expect(fixture.nativeElement.textContent).toContain('recent-low@capstone.local');
  });
});
