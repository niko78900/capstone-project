import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of } from 'rxjs';
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
    rewardsService.getLeaderboard.and.returnValue(
      of({
        window: 'ALL_TIME',
        limit: 50,
        entries: [
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
      }),
    );
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
      providers: [provideNoopAnimations(), { provide: RewardsService, useValue: rewardsService }],
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
});
