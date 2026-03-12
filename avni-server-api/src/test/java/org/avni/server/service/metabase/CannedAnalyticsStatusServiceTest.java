package org.avni.server.service.metabase;

import org.avni.server.config.SelfServiceBatchConfig;
import org.avni.server.dao.ImplementationRepository;
import org.avni.server.domain.Organisation;
import org.avni.server.domain.metabase.CannedAnalyticsStatus;
import org.avni.server.service.batch.BatchJobService;
import org.avni.server.service.OrganisationConfigService;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.util.HashMap;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class CannedAnalyticsStatusServiceTest {
    @Mock private OrganisationConfigService organisationConfigService;
    @Mock private BatchJobService batchJobService;
    @Mock private ImplementationRepository implementationRepository;
    @Mock private MetabaseService metabaseService;
    @Mock private SelfServiceBatchConfig selfServiceBatchConfig;
    @Mock private Organisation organisation;
    
    private CannedAnalyticsStatusService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new CannedAnalyticsStatusService(
            organisationConfigService, batchJobService, true,
            implementationRepository, metabaseService, selfServiceBatchConfig
        );
    }
    
    @Test
    public void testGetStatusWhenETLNotRun() {
        when(implementationRepository.hasETLRun(organisation)).thenReturn(false);
        when(batchJobService.getCannedAnalyticsJobStatus(organisation)).thenReturn(new HashMap<>());
        when(selfServiceBatchConfig.getTotalTimeoutInMillis()).thenReturn(Integer.valueOf(1000));
        
        CannedAnalyticsStatus status = service.getStatus(organisation);
        
        assertNotNull(status);
    }
}
