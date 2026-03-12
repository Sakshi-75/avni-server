package org.avni.server.exporter;

import org.avni.server.dao.AvniJobRepository;
import org.avni.server.dao.ExportJobParametersRepository;
import org.avni.server.domain.Organisation;
import org.avni.server.domain.User;
import org.avni.server.domain.UserContext;
import org.avni.server.framework.security.UserContextHolder;
import org.avni.server.web.util.ErrorBodyBuilder;
import org.avni.server.web.external.request.export.ExportJobRequest;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ExportJobServiceTest {
    @Mock private AvniJobRepository avniJobRepository;
    @Mock private Job exportVisitJob;
    @Mock private Job exportV2Job;
    @Mock private JobLauncher bgJobLauncher;
    @Mock private ExportJobParametersRepository exportJobParametersRepository;
    @Mock private ErrorBodyBuilder errorBodyBuilder;
    
    private ExportJobService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ExportJobService(exportVisitJob, bgJobLauncher, avniJobRepository, 
                exportV2Job, exportJobParametersRepository, errorBodyBuilder);
    }
    
    @Test
    public void testRunExportJobWithoutMediaDirectory() {
        UserContext userContext = mock(UserContext.class);
        Organisation org = mock(Organisation.class);
        when(userContext.getOrganisation()).thenReturn(org);
        when(org.getMediaDirectory()).thenReturn(null);
        UserContextHolder.create(userContext);
        
        ExportJobRequest request = new ExportJobRequest();
        ResponseEntity<?> response = service.runExportJob(request);
        
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("Media Directory"));
    }
}
