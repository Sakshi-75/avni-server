package org.avni.server.service;

import org.avni.server.dao.ConceptRepository;
import org.avni.server.dao.OrganisationConfigRepository;
import org.avni.server.dao.SubjectTypeRepository;
import org.avni.server.domain.Organisation;
import org.avni.server.domain.OrganisationConfig;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.data.projection.ProjectionFactory;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class OrganisationConfigServiceTest {
    @Mock private OrganisationConfigRepository organisationConfigRepository;
    @Mock private ProjectionFactory projectionFactory;
    @Mock private ConceptRepository conceptRepository;
    @Mock private LocationHierarchyService locationHierarchyService;
    @Mock private SubjectTypeRepository subjectTypeRepository;
    @Mock private Organisation organisation;
    
    private OrganisationConfigService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new OrganisationConfigService(
            organisationConfigRepository, projectionFactory, conceptRepository,
            locationHierarchyService, subjectTypeRepository
        );
    }
    
    @Test
    public void testGetOrganisationConfig() {
        OrganisationConfig config = new OrganisationConfig();
        when(organisation.getId()).thenReturn(1L);
        when(organisationConfigRepository.findByOrganisationId(1L)).thenReturn(config);
        
        OrganisationConfig result = service.getOrganisationConfig(organisation);
        
        assertNotNull(result);
        verify(organisationConfigRepository).findByOrganisationId(1L);
    }
}
